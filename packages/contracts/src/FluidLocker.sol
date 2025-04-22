// SPDX-License-Identifier: MIT

//                      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { Math } from "@openzeppelin-v5/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";
import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IERC20 } from "@openzeppelin-v5/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";
import { IWETH9 } from "./token/IWETH9.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Interfaces */
import { IEPProgramManager } from "./interfaces/IEPProgramManager.sol";
import { IFluidLocker } from "./interfaces/IFluidLocker.sol";
import { IStakingRewardController } from "./interfaces/IStakingRewardController.sol";
import { IFontaine } from "./interfaces/IFontaine.sol";
import { ILiquidityPoolController } from "./interfaces/ILiquidityPoolController.sol";

/* Uniswap V3 Interfaces */
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import { IV3SwapRouter } from "@uniswap/swap-router-contracts/contracts/interfaces/IV3SwapRouter.sol";
import { TransferHelper } from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import { TickMath } from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

using SuperTokenV1Library for ISuperToken;
using SafeCast for int256;

/// @dev Basis points denominator (for percentage calculation)
uint256 constant BP_DENOMINATOR = 10_000;

/// @dev Scaler used for unlock percentage calculation
uint256 constant UNLOCKING_PCT_SCALER = 1e18;

function calculateVestUnlockFlowRates(uint256 amountToUnlock, uint128 unlockPeriod)
    pure
    returns (int96 unlockFlowRate, int96 taxFlowRate)
{
    int96 globalFlowRate = int256(amountToUnlock / unlockPeriod).toInt96();

    unlockFlowRate =
        (globalFlowRate * int256(getUnlockingPercentage(unlockPeriod))).toInt96() / int256(BP_DENOMINATOR).toInt96();
    taxFlowRate = globalFlowRate - unlockFlowRate;
}

function getUnlockingPercentage(uint128 unlockPeriod) pure returns (uint256 unlockingPercentageBP) {
    unlockingPercentageBP = (
        2_000 + ((8_000 * Math.sqrt(unlockPeriod * UNLOCKING_PCT_SCALER)) / Math.sqrt(365 days * UNLOCKING_PCT_SCALER))
    );
}

/**
 * @title Locker Contract
 * @author Superfluid
 * @notice Contract responsible for locking and holding FLUID token on behalf of users
 *
 */
contract FluidLocker is Initializable, ReentrancyGuard, IFluidLocker {
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid GDA Tax Distribution Pool interface
    ISuperfluidPool public immutable TAX_DISTRIBUTION_POOL;

    /// @notice Distribution Program Manager interface
    IEPProgramManager public immutable EP_PROGRAM_MANAGER;

    /// @notice Staking Reward Controller interface
    IStakingRewardController public immutable STAKING_REWARD_CONTROLLER;

    /// @notice Fontaine Beacon contract address
    UpgradeableBeacon public immutable FONTAINE_BEACON;

    /// @notice Boolean sets to True if unlock is available
    bool public immutable UNLOCK_AVAILABLE;

    /// @notice Staking cooldown period
    uint80 private constant _STAKING_COOLDOWN_PERIOD = 3 days;

    /// @notice Minimum unlock period allowed (1 week)
    uint128 private constant _MIN_UNLOCK_PERIOD = 7 days;

    /// @notice Maximum unlock period allowed (12 months)
    uint128 private constant _MAX_UNLOCK_PERIOD = 365 days;

    /// @notice Instant unlock penalty percentage (expressed in basis points)
    uint256 private constant _INSTANT_UNLOCK_PENALTY_BP = 8_000;

    /// @notice Scaler used for unlock percentage calculation
    uint256 private constant _PERCENT_TO_BP = 100;

    //   _    __ ___     ____                          __        __    __         _____ __        __
    //  | |  / /|__ \   /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__      / ___// /_____ _/ /____  _____
    //  | | / /__/ /    / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //  | |/ // __/   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  |___//____/  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice Uniswap V3 Router interface
    IV3SwapRouter public immutable SWAP_ROUTER;

    /// @notice Uniswap V3 Nonfungible Position Manager interface
    INonfungiblePositionManager public immutable NONFUNGIBLE_POSITION_MANAGER;

    /// @notice Liquidity Pool Controller interface
    ILiquidityPoolController public immutable LIQUIDITY_POOL_CONTROLLER;

    /// @notice Pump percentage (expressed in basis points)
    uint256 public constant BP_PUMP_RATIO = 100; // 1%

    /// @notice Slippage tolerance (expressed in basis points)
    uint256 public constant BP_SLIPPAGE_TOLERANCE = 500; // 5%

    /// @notice Liquidity operation deadline
    uint256 public constant LP_OPERATION_DEADLINE = 1 minutes;

    /// @notice Tax free withdraw delay
    uint256 public constant TAX_FREE_WITHDRAW_DELAY = 180 days;

    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice This locker owner address
    address public lockerOwner;

    /// @notice Timestamp at which the staking cooldown period is elapsed
    uint80 public stakingUnlocksAt;

    /// @notice Total unlock count
    uint16 public fontaineCount;

    /// @notice Balance of $FLUID token staked in this locker
    uint256 private _stakedBalance;

    /// @notice Stores the Fontaine contract associated to the given unlock identifier
    mapping(uint256 unlockId => IFontaine fontaine) public fontaines;

    //   _    __ ___      _____ __        __
    //  | |  / /|__ \    / ___// /_____ _/ /____  _____
    //  | | / /__/ /    \__ \/ __/ __ `/ __/ _ \/ ___/
    //  | |/ // __/    ___/ / /_/ /_/ / /_/  __(__  )
    //  |___//____/   /____/\__/\__,_/\__/\___/____/

    /// @notice Stores the Uniswap V3 position token identifier for a given pool identifier
    mapping(address pool => uint256 positionTokenId) public positionTokenIds;

    /// @notice Stores the tax free withdraw timestamp for a given position token identifier
    mapping(uint256 positionTokenId => uint256 taxFreeWithdrawTimestamp) public positionExitTimestamps;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Locker contract constructor
     * @param fluid FLUID SuperToken contract interface
     * @param taxDistributionPool Tax Distribution Pool GDA contract interface
     * @param programManager Ecosystem Partner Program Manager contract interface
     * @param stakingRewardController Staking Reward Controller contract interface
     * @param fontaineBeacon Fontaine Beacon contract address
     * @param isUnlockAvailable True if the unlock is available, false otherwise
     */
    constructor(
        ISuperToken fluid,
        ISuperfluidPool taxDistributionPool,
        IEPProgramManager programManager,
        IStakingRewardController stakingRewardController,
        address fontaineBeacon,
        bool isUnlockAvailable,
        INonfungiblePositionManager nonfungiblePositionManager,
        ILiquidityPoolController liquidityPoolController,
        IV3SwapRouter swapRouter
    ) {
        // Disable initializers to prevent implementation contract initalization
        _disableInitializers();

        // Sets immutable states
        UNLOCK_AVAILABLE = isUnlockAvailable;
        FLUID = fluid;
        TAX_DISTRIBUTION_POOL = taxDistributionPool;
        EP_PROGRAM_MANAGER = programManager;
        STAKING_REWARD_CONTROLLER = stakingRewardController;

        // Sets the Fontaine beacon address
        FONTAINE_BEACON = UpgradeableBeacon(fontaineBeacon);

        SWAP_ROUTER = swapRouter;
        NONFUNGIBLE_POSITION_MANAGER = nonfungiblePositionManager;
        LIQUIDITY_POOL_CONTROLLER = liquidityPoolController;
    }

    /**
     * @notice Locker contract initializer
     * @param owner this Locker contract owner account
     */
    function initialize(address owner) external initializer {
        // Sets the owner of this locker
        lockerOwner = owner;
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLocker
    function claim(uint256 programId, uint256 totalProgramUnits, uint256 nonce, bytes memory stackSignature)
        external
        nonReentrant
    {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        if (!FLUID.isMemberConnected(address(programPool), address(this))) {
            // Connect this locker to the Program Pool
            FLUID.connectPool(programPool);
        }

        // Request program manager to update this locker's units
        EP_PROGRAM_MANAGER.updateUserUnits(lockerOwner, programId, totalProgramUnits, nonce, stackSignature);

        emit IFluidLocker.FluidStreamClaimed(programId, totalProgramUnits);
    }

    /// @inheritdoc IFluidLocker
    function claim(
        uint256[] memory programIds,
        uint256[] memory totalProgramUnits,
        uint256 nonce,
        bytes memory stackSignature
    ) external nonReentrant {
        for (uint256 i = 0; i < programIds.length; ++i) {
            // Get the corresponding program pool
            ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programIds[i]);

            if (!FLUID.isMemberConnected(address(programPool), address(this))) {
                // Connect this locker to the Program Pool
                FLUID.connectPool(programPool);
            }
        }

        // Request program manager to update this locker's units
        EP_PROGRAM_MANAGER.batchUpdateUserUnits(lockerOwner, programIds, totalProgramUnits, nonce, stackSignature);

        emit IFluidLocker.FluidStreamsClaimed(programIds, totalProgramUnits);
    }

    /// @inheritdoc IFluidLocker
    function lock(uint256 amount) external nonReentrant {
        // Fetch the amount of FLUID Token to be locked from the caller
        FLUID.transferFrom(msg.sender, address(this), amount);

        emit FluidLocked(amount);
    }

    /// @inheritdoc IFluidLocker
    function unlock(uint256 unlockAmount, uint128 unlockPeriod, address recipient)
        external
        nonReentrant
        onlyLockerOwner
        unlockAvailable
    {
        // Enforce unlock period validity
        if (unlockPeriod != 0 && (unlockPeriod < _MIN_UNLOCK_PERIOD || unlockPeriod > _MAX_UNLOCK_PERIOD)) {
            revert INVALID_UNLOCK_PERIOD();
        }

        // Ensure recipient is not the zero-address
        if (recipient == address(0)) {
            revert FORBIDDEN();
        }

        // Ensure that the unlock amount is not greater than the available balance
        if (unlockAmount > getAvailableBalance()) {
            revert INSUFFICIENT_AVAILABLE_BALANCE();
        }

        // Ensure that the tax distribution pools has at least one unit distributed
        if (TAX_DISTRIBUTION_POOL.getTotalUnits() == 0) {
            revert TAX_DISTRIBUTION_POOL_HAS_NO_UNITS();
        }

        if (unlockPeriod == 0) {
            _instantUnlock(unlockAmount, recipient);
        } else {
            _vestUnlock(unlockAmount, unlockPeriod, recipient);
        }
    }

    /// @inheritdoc IFluidLocker
    function stake(uint256 amountToStake) external nonReentrant onlyLockerOwner unlockAvailable {
        if (amountToStake > getAvailableBalance()) revert INSUFFICIENT_AVAILABLE_BALANCE();

        if (!FLUID.isMemberConnected(address(TAX_DISTRIBUTION_POOL), address(this))) {
            // Connect this locker to the Tax Distribution Pool
            FLUID.connectPool(TAX_DISTRIBUTION_POOL);
        }

        // Update staked balance
        _stakedBalance += amountToStake;

        // Update unlock timestamp
        stakingUnlocksAt = uint80(block.timestamp) + _STAKING_COOLDOWN_PERIOD;

        // Call Staking Reward Controller to update staker's units
        STAKING_REWARD_CONTROLLER.updateStakerUnits(_stakedBalance);

        emit FluidStaked(_stakedBalance, amountToStake);
    }

    /// @inheritdoc IFluidLocker
    function unstake(uint256 amountToUnstake) external nonReentrant onlyLockerOwner unlockAvailable {
        if (block.timestamp < stakingUnlocksAt) {
            revert STAKING_COOLDOWN_NOT_ELAPSED();
        }

        // Enforce amount to unstake is not greater than the staked balance
        if (amountToUnstake > _stakedBalance) {
            revert INSUFFICIENT_STAKED_BALANCE();
        }

        // Update the staked balance
        _stakedBalance -= amountToUnstake;

        // Call Staking Reward Controller to update staker's units
        STAKING_REWARD_CONTROLLER.updateStakerUnits(_stakedBalance);

        // Disconnect this locker from the Tax Distribution Pool
        FLUID.disconnectPool(TAX_DISTRIBUTION_POOL);

        emit FluidUnstaked();
    }

    /// @inheritdoc IFluidLocker
    function connectToPool(uint256 programId) external nonReentrant onlyLockerOwner {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        if (!FLUID.isMemberConnected(address(programPool), address(this))) {
            // Connect this locker to the Program Pool
            FLUID.connectPool(programPool);
        }
    }

    /// @inheritdoc IFluidLocker
    function disconnectFromPool(uint256 programId) external nonReentrant onlyLockerOwner {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        if (FLUID.isMemberConnected(address(programPool), address(this))) {
            // Connect this locker to the Program Pool
            FLUID.disconnectPool(programPool);
        }
    }

    /// @inheritdoc IFluidLocker
    function provideLiquidity(uint256 poolId, uint256 pairedAssetAmount, uint256 supPumpAmountMin, uint256 supLPAmount)
        external
        payable
        nonReentrant
        onlyLockerOwner
    {
        // Get the corresponding liquidity pool
        IUniswapV3Pool liquidityPool = IUniswapV3Pool(LIQUIDITY_POOL_CONTROLLER.getLiquidityPool(poolId));

        // Ensure the liquidity pool is approved
        if (address(liquidityPool) == address(0)) {
            revert LIQUIDITY_POOL_NOT_APPROVED();
        }

        // Get the paired asset
        address pairedAsset = liquidityPool.token0() == address(FLUID) ? liquidityPool.token1() : liquidityPool.token0();

        if (pairedAsset == NONFUNGIBLE_POSITION_MANAGER.WETH9()) {
            // Check that the amount of ETH sent is equal to the paired asset amount
            if (msg.value != pairedAssetAmount) {
                revert INSUFFICIENT_ETH_SENT();
            }

            // Wrap ETH into WETH
            IWETH9(pairedAsset).deposit{ value: pairedAssetAmount }();
        } else {
            // Transfer the paired asset from the caller to the locker
            TransferHelper.safeTransferFrom(pairedAsset, msg.sender, address(this), pairedAssetAmount);
        }

        // Pumponomics (market buy SUP with 1% of the provided paired asset)
        _pump(
            IUniswapV3Pool(liquidityPool),
            pairedAsset,
            pairedAssetAmount * BP_PUMP_RATIO / BP_DENOMINATOR,
            supPumpAmountMin
        );

        // Get the amount of paired asset tokens in the locker
        uint256 pairedAssetLPAmount = IERC20(pairedAsset).balanceOf(address(this));

        // Approve the locker to spend the paired asset and the $SUP tokens
        TransferHelper.safeApprove(pairedAsset, address(NONFUNGIBLE_POSITION_MANAGER), pairedAssetLPAmount);
        TransferHelper.safeApprove(address(FLUID), address(NONFUNGIBLE_POSITION_MANAGER), supLPAmount);

        // Create a new Uniswap V3 position
        _createPosition(liquidityPool, pairedAssetLPAmount, supLPAmount);
    }

    /// @inheritdoc IFluidLocker
    function withdrawLiquidity(
        uint256 poolId,
        uint128 liquidityToRemove,
        uint256 amount0ToRemove,
        uint256 amount1ToRemove
    ) external nonReentrant onlyLockerOwner {
        // Get the corresponding liquidity pool
        IUniswapV3Pool liquidityPool = IUniswapV3Pool(LIQUIDITY_POOL_CONTROLLER.getLiquidityPool(poolId));

        // Ensure the liquidity pool is approved
        if (address(liquidityPool) == address(0)) {
            revert LIQUIDITY_POOL_NOT_APPROVED();
        }

        // ensure the locker has a position
        if (!_hasPosition(address(liquidityPool))) {
            revert LOCKER_HAS_NO_POSITION();
        }

        address pairedAsset = liquidityPool.token0() == address(FLUID) ? liquidityPool.token1() : liquidityPool.token0();

        uint256 positionTokenId = positionTokenIds[address(liquidityPool)];

        (,,,,,,, uint128 positionLiquidity,,,,) = NONFUNGIBLE_POSITION_MANAGER.positions(positionTokenId);

        (, uint256 withdrawnSup) =
            _decreasePosition(positionTokenId, liquidityToRemove, amount0ToRemove, amount1ToRemove);

        // Burn the position and delete position tokenId if all liquidity is removed
        if (liquidityToRemove == positionLiquidity) {
            NONFUNGIBLE_POSITION_MANAGER.burn(positionTokenId);
            delete positionTokenIds[address(liquidityPool)];
        }

        // transfer the paired asset tokens back to the owner
        TransferHelper.safeTransfer(pairedAsset, lockerOwner, IERC20(pairedAsset).balanceOf(address(this)));

        if (block.timestamp >= positionExitTimestamps[positionTokenId]) {
            TransferHelper.safeTransfer(address(FLUID), lockerOwner, withdrawnSup);
        }
    }

    /// @inheritdoc IFluidLocker
    function collectFees(uint256 poolId)
        external
        nonReentrant
        onlyLockerOwner
        returns (uint256 collectedAsset, uint256 collectedSup)
    {
        // Get the liquidity pool corresponding to the pool identifier
        IUniswapV3Pool liquidityPool = IUniswapV3Pool(LIQUIDITY_POOL_CONTROLLER.getLiquidityPool(poolId));

        // ensure the locker has a position
        if (!_hasPosition(address(liquidityPool))) revert LOCKER_HAS_NO_POSITION();

        uint256 positionTokenId = positionTokenIds[address(liquidityPool)];

        if (liquidityPool.token0() == address(FLUID)) {
            // Collect the fees
            (collectedSup, collectedAsset) = _collect(positionTokenId);

            // Transfer the paired asset tokens back to the owner
            TransferHelper.safeTransfer(liquidityPool.token1(), lockerOwner, collectedAsset);
        } else {
            // Collect the fees
            (collectedAsset, collectedSup) = _collect(positionTokenId);

            // Transfer the paired asset tokens back to the owner
            TransferHelper.safeTransfer(liquidityPool.token0(), lockerOwner, collectedAsset);
        }

        // Transfer the collected fees to the locker owner
        TransferHelper.safeTransfer(address(FLUID), lockerOwner, collectedSup);
    }

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLocker
    function getFlowRatePerProgram(uint256 programId) public view returns (int96 flowRate) {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        // Get the flow rate
        flowRate = programPool.getMemberFlowRate(address(this));
    }

    /// @inheritdoc IFluidLocker
    function getFlowRatePerProgram(uint256[] memory programIds) external view returns (int96[] memory flowRates) {
        flowRates = new int96[](programIds.length);

        for (uint256 i = 0; i < programIds.length; ++i) {
            flowRates[i] = getFlowRatePerProgram(programIds[i]);
        }
    }

    /// @inheritdoc IFluidLocker
    function getUnitsPerProgram(uint256 programId) public view returns (uint128 units) {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        // Get this locker's unit within the given program identifier
        units = programPool.getUnits(address(this));
    }

    /// @inheritdoc IFluidLocker
    function getUnitsPerProgram(uint256[] memory programIds) external view returns (uint128[] memory units) {
        units = new uint128[](programIds.length);

        for (uint256 i = 0; i < programIds.length; ++i) {
            units[i] = getUnitsPerProgram(programIds[i]);
        }
    }

    /// @inheritdoc IFluidLocker
    function getStakedBalance() external view returns (uint256 sBalance) {
        sBalance = _stakedBalance;
    }

    /// @inheritdoc IFluidLocker
    function getAvailableBalance() public view returns (uint256 aBalance) {
        aBalance = FLUID.balanceOf(address(this)) - _stakedBalance;
    }

    /// @inheritdoc IFluidLocker
    function getFontaineBeaconImplementation() public view returns (address fontaineBeaconImpl) {
        fontaineBeaconImpl = FONTAINE_BEACON.implementation();
    }

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    function _instantUnlock(uint256 amountToUnlock, address recipient) internal {
        // Calculate instant unlock penalty amount
        uint256 penaltyAmount = (amountToUnlock * _INSTANT_UNLOCK_PENALTY_BP) / BP_DENOMINATOR;

        // Distribute penalty to staker (connected to the TAX_DISTRIBUTION_POOL)
        uint256 actualPenaltyAmount = FLUID.distribute(address(this), TAX_DISTRIBUTION_POOL, penaltyAmount);

        // Transfer the leftover $FLUID to the locker owner
        FLUID.transfer(recipient, amountToUnlock - actualPenaltyAmount);

        emit FluidUnlocked(0, amountToUnlock, recipient, address(0));
    }

    function _vestUnlock(uint256 amountToUnlock, uint128 unlockPeriod, address recipient) internal {
        // Calculate the unlock and penalty flow rates based on requested amount and unlock period
        (int96 unlockFlowRate, int96 taxFlowRate) = calculateVestUnlockFlowRates(amountToUnlock, unlockPeriod);

        // Use create2 to deploy a Fontaine Beacon Proxy
        // The salt used for deployment is the hashed encoded Locker address and unlock identifier
        address newFontaine = address(
            new BeaconProxy{ salt: keccak256(abi.encode(address(this), fontaineCount)) }(address(FONTAINE_BEACON), "")
        );

        // Transfer the total amount to unlock to the newly created Fontaine
        FLUID.transfer(newFontaine, amountToUnlock);

        // Persist the fontaine address and increment fontaine counter
        fontaines[fontaineCount] = IFontaine(newFontaine);
        fontaineCount++;

        // Initialize the new Fontaine instance (this initiate the unlock process)
        IFontaine(newFontaine).initialize(recipient, unlockFlowRate, taxFlowRate, unlockPeriod);

        emit FluidUnlocked(unlockPeriod, amountToUnlock, recipient, newFontaine);
    }

    /**
     * @notice Swaps paired asset for FLUID tokens using Uniswap V3 (Pumponomics)
     * @param pool The Uniswap V3 pool to perform the swap in
     * @param pairedAsset The address of the paired asset to swap from
     * @param pairedAssetAmount The amount of paired asset to swap
     * @param supAmountMinimum The minimum amount of FLUID tokens to receive
     */
    function _pump(IUniswapV3Pool pool, address pairedAsset, uint256 pairedAssetAmount, uint256 supAmountMinimum)
        internal
    {
        IERC20(pairedAsset).approve(address(SWAP_ROUTER), pairedAssetAmount);

        IV3SwapRouter.ExactInputSingleParams memory swapParams = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: pairedAsset,
            tokenOut: address(FLUID),
            fee: pool.fee(),
            recipient: address(this),
            amountIn: pairedAssetAmount,
            amountOutMinimum: supAmountMinimum,
            sqrtPriceLimitX96: 0
        });

        SWAP_ROUTER.exactInputSingle(swapParams);
    }

    /**
     * @notice Creates a new Uniswap V3 position with the specified amounts of tokens
     * @param pool The Uniswap V3 pool to create the position in
     * @param pairedAssetAmount The desired amount of token0 to add as liquidity
     * @param supAmount The desired amount of token1 to add as liquidity
     * @return depositedPairedAssetAmount The actual amount of paired asset deposited as liquidity
     * @return depositedSupAmount The actual amount of $FLUID deposited as liquidity
     */
    function _createPosition(IUniswapV3Pool pool, uint256 pairedAssetAmount, uint256 supAmount)
        internal
        returns (uint256 depositedPairedAssetAmount, uint256 depositedSupAmount)
    {
        bool zeroIsSup = pool.token0() == address(FLUID);

        INonfungiblePositionManager.MintParams memory mintParams =
            _formatMintParams(pool, zeroIsSup, pairedAssetAmount, supAmount);

        // Create the UniswapV3 position
        (uint256 tokenId,, uint256 depositedAmount0, uint256 depositedAmount1) =
            NONFUNGIBLE_POSITION_MANAGER.mint(mintParams);

        // Store the position
        positionTokenIds[address(pool)] = tokenId;

        // Set the tax free withdraw timestamp
        positionExitTimestamps[tokenId] = block.timestamp + TAX_FREE_WITHDRAW_DELAY;

        (depositedSupAmount, depositedPairedAssetAmount) =
            _sortOutAmounts(zeroIsSup, depositedAmount0, depositedAmount1);
    }

    /**
     * @notice Increases liquidity in a Uniswap V3 position
     * @param tokenId The ID of the NFT position to increase liquidity in
     * @param pairedAssetAmount The desired amount of paired asset to add as liquidity
     * @param supAmount The desired amount of $FLUID to add as liquidity
     * @return depositedPairedAssetAmount The actual amount of paired asset deposited as liquidity
     * @return depositedSupAmount The actual amount of $FLUID deposited as liquidity
     */
    function _increasePosition(uint256 tokenId, uint256 pairedAssetAmount, uint256 supAmount)
        internal
        returns (uint256 depositedPairedAssetAmount, uint256 depositedSupAmount)
    {
        (,, address token0,,,,,,,,,) = NONFUNGIBLE_POSITION_MANAGER.positions(tokenId);
        bool zeroIsSup = token0 == address(FLUID);

        (uint256 amount0, uint256 amount1) = _sortInAmounts(zeroIsSup, supAmount, pairedAssetAmount);
        (uint256 amount0Min, uint256 amount1Min) = _calculateMinAmounts(amount0, amount1);

        // Build Increase Liquidity parameters
        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
            .IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: block.timestamp + LP_OPERATION_DEADLINE
        });

        (, uint256 depositedAmount0, uint256 depositedAmount1) = NONFUNGIBLE_POSITION_MANAGER.increaseLiquidity(params);

        (depositedSupAmount, depositedPairedAssetAmount) =
            _sortOutAmounts(zeroIsSup, depositedAmount0, depositedAmount1);
    }

    /**
     * @notice Decreases liquidity from a Uniswap V3 position
     * @param tokenId The ID of the NFT position to decrease liquidity from
     * @param liquidityToRemove The amount of liquidity to remove from the position (only collect fees if set to 0)
     * @param pairedAssetAmountToRemove The minimum amount of paired asset to remove from the position
     * @param supAmountToRemove The minimum amount of $FLUID to remove from the position
     * @return withdrawnPairedAssetAmount The amount of paired asset received from removing liquidity
     * @return withdrawnSupAmount The amount of $FLUID received from removing liquidity
     */
    function _decreasePosition(
        uint256 tokenId,
        uint128 liquidityToRemove,
        uint256 pairedAssetAmountToRemove,
        uint256 supAmountToRemove
    ) internal returns (uint256 withdrawnPairedAssetAmount, uint256 withdrawnSupAmount) {
        (,, address token0,,,,,,,,,) = NONFUNGIBLE_POSITION_MANAGER.positions(tokenId);
        bool zeroIsSup = token0 == address(FLUID);

        (uint256 amount0, uint256 amount1) = _sortInAmounts(zeroIsSup, supAmountToRemove, pairedAssetAmountToRemove);
        (uint256 amount0Min, uint256 amount1Min) = _calculateMinAmounts(amount0, amount1);

        // construct Decrease Liquidity parameters
        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
            .DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: liquidityToRemove,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: block.timestamp + LP_OPERATION_DEADLINE
        });

        NONFUNGIBLE_POSITION_MANAGER.decreaseLiquidity(params);

        // Collect the tokens owed
        (uint256 withdrawnAmount0, uint256 withdrawnAmount1) = _collect(tokenId);

        (withdrawnSupAmount, withdrawnPairedAssetAmount) =
            _sortOutAmounts(zeroIsSup, withdrawnAmount0, withdrawnAmount1);
    }

    /**
     * @notice Collects accumulated fees from a Uniswap V3 position
     * @param tokenId The ID of the NFT position to collect fees from
     * @return amount0 The amount of token0 fees collected
     * @return amount1 The amount of token1 fees collected
     */
    function _collect(uint256 tokenId) internal returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (amount0, amount1) = NONFUNGIBLE_POSITION_MANAGER.collect(collectParams);
    }

    function _formatMintParams(IUniswapV3Pool pool, bool zeroIsSup, uint256 pairedAssetAmount, uint256 supAmount)
        internal
        view
        returns (INonfungiblePositionManager.MintParams memory mintParams)
    {
        (uint256 amount0, uint256 amount1) = _sortInAmounts(zeroIsSup, supAmount, pairedAssetAmount);
        (uint256 amount0Min, uint256 amount1Min) = _calculateMinAmounts(amount0, amount1);

        int24 tickSpacing = pool.tickSpacing();

        mintParams = INonfungiblePositionManager.MintParams({
            token0: pool.token0(),
            token1: pool.token1(),
            fee: pool.fee(),
            tickLower: (TickMath.MIN_TICK / tickSpacing) * tickSpacing,
            tickUpper: (TickMath.MAX_TICK / tickSpacing) * tickSpacing,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            recipient: address(this),
            deadline: block.timestamp + LP_OPERATION_DEADLINE
        });
    }

    /**
     * @notice Calculates minimum amounts based on slippage tolerance
     * @param amount0 The ideal amount of token0
     * @param amount1 The ideal amount of token1
     * @return amount0Min The minimum acceptable amount of token0
     * @return amount1Min The minimum acceptable amount of token1
     */
    function _calculateMinAmounts(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint256 amount0Min, uint256 amount1Min)
    {
        // Calculate minimum amounts with slippage protection
        unchecked {
            amount0Min = (amount0 * (BP_DENOMINATOR - BP_SLIPPAGE_TOLERANCE)) / BP_DENOMINATOR;
            amount1Min = (amount1 * (BP_DENOMINATOR - BP_SLIPPAGE_TOLERANCE)) / BP_DENOMINATOR;
        }
    }

    /**
     * @notice Checks if the locker has an active Uniswap V3 position
     * @param pool The pool address to query
     * @return hasPosition True if the locker has a position, false otherwise
     */
    function _hasPosition(address pool) internal view returns (bool hasPosition) {
        hasPosition = positionTokenIds[pool] != 0;
    }

    /**
     * @notice Sorts input amounts based on token order in the Uniswap V3 pool
     * @param zeroIsSup Whether SUP is token0 in the pool
     * @param supAmount The amount of SUP tokens
     * @param pairedAssetAmount The amount of paired asset tokens
     * @return amount0 The amount of token0 after sorting
     * @return amount1 The amount of token1 after sorting
     */
    function _sortInAmounts(bool zeroIsSup, uint256 supAmount, uint256 pairedAssetAmount)
        internal
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        if (zeroIsSup) {
            amount0 = supAmount;
            amount1 = pairedAssetAmount;
        } else {
            amount0 = pairedAssetAmount;
            amount1 = supAmount;
        }
    }

    /**
     * @notice Sorts output amounts based on token order in the Uniswap V3 pool
     * @param zeroIsSup Whether SUP is token0 in the pool
     * @param amount0 The amount of token0 to sort
     * @param amount1 The amount of token1 to sort
     * @return supAmount The sorted SUP token amount
     * @return pairedAssetAmount The sorted paired asset amount
     */
    function _sortOutAmounts(bool zeroIsSup, uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint256 supAmount, uint256 pairedAssetAmount)
    {
        if (zeroIsSup) {
            supAmount = amount0;
            pairedAssetAmount = amount1;
        } else {
            supAmount = amount1;
            pairedAssetAmount = amount0;
        }
    }

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @dev Throws if called by any account other than the owner
     */
    modifier onlyLockerOwner() {
        if (msg.sender != lockerOwner) revert NOT_LOCKER_OWNER();
        _;
    }

    /**
     * @dev Throws if called operation is not available
     */
    modifier unlockAvailable() {
        if (!UNLOCK_AVAILABLE) revert TTE_NOT_ACTIVATED();
        _;
    }
}
