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

import { ReentrancyGuard } from "solady/utils/ReentrancyGuard.sol";

/* Uniswap V4 Interfaces */
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { IPositionManager } from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { PoolIdLibrary } from "@uniswap/v4-core/src/types/PoolId.sol";
import { StateLibrary } from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import { LiquidityAmounts } from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { IPermit2 } from "@uniswap/v4-periphery/lib/permit2/src/interfaces/IPermit2.sol";

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

    IERC20 public immutable USDC;
    IERC20 public immutable WETH;
    IPositionManager public immutable POSITION_MANAGER;
    IPoolManager public immutable POOL_MANAGER;
    address public immutable PERMIT2;
    uint256 private immutable _LP_OPERATION_DEADLINE = 15 seconds;

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

    PoolKey public usdcPoolKey;
    PoolKey public wethPoolKey;
    mapping(PoolKey poolKey => uint256 tokenId) public positonTokenId;

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
        bool isUnlockAvailable
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
    function unlock(uint128 unlockPeriod, address recipient) external nonReentrant onlyLockerOwner unlockAvailable {
        // Enforce unlock period validity
        if (unlockPeriod != 0 && (unlockPeriod < _MIN_UNLOCK_PERIOD || unlockPeriod > _MAX_UNLOCK_PERIOD)) {
            revert INVALID_UNLOCK_PERIOD();
        }

        // Ensure recipient is not the zero-address
        if (recipient == address(0)) {
            revert FORBIDDEN();
        }

        // Ensure that the tax distribution pools has at least one unit distributed
        if (TAX_DISTRIBUTION_POOL.getTotalUnits() == 0) {
            revert TAX_DISTRIBUTION_POOL_HAS_NO_UNITS();
        }

        // Get balance available for unlocking
        uint256 availableBalance = getAvailableBalance();

        // Revert if there is no FLUID to unlock
        if (availableBalance == 0) revert NO_FLUID_TO_UNLOCK();

        if (unlockPeriod == 0) {
            _instantUnlock(availableBalance, recipient);
        } else {
            _vestUnlock(availableBalance, unlockPeriod, recipient);
        }
    }

    /// @inheritdoc IFluidLocker
    function stake() external nonReentrant onlyLockerOwner unlockAvailable {
        uint256 amountToStake = getAvailableBalance();

        if (amountToStake == 0) revert NO_FLUID_TO_STAKE();

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
    function unstake() external nonReentrant onlyLockerOwner unlockAvailable {
        if (block.timestamp < stakingUnlocksAt) {
            revert STAKING_COOLDOWN_NOT_ELAPSED();
        }

        // Enfore staked balance is not zero
        if (_stakedBalance == 0) revert NO_FLUID_TO_UNSTAKE();

        // Set staked balance to 0
        _stakedBalance = 0;

        // Call Staking Reward Controller to update staker's units
        STAKING_REWARD_CONTROLLER.updateStakerUnits(0);

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

    /**
     * @notice Provides liquidity to the WETH/SUP pool
     * @param supAmountMax The maximum amount of SUP to provide as liquidity
     * @param wethAmountMax The maximum amount of WETH to provide as liquidity
     */
    function provideLiquidityWETH(uint256 supAmountMax, uint256 wethAmountMax) external nonReentrant onlyLockerOwner {
        // Transfer WETH from the caller to this locker
        WETH.transferFrom(msg.sender, address(this), wethAmountMax);

        // Revert if the amount of $FLUID to provide is greater than the available balance
        if (supAmountMax > getAvailableBalance()) {
            /// NOTE / FIXME : here we may want to hard-set the max amount of SUP to getAvailableBalance(). (thoughts?)
            revert INSUFFICIENT_BALANCE();
        }

        /// TODO / FIXME : here we may need to market buy some SUP (pumponomics)

        if (_lockerHasPosition(wethPoolKey)) {
            _increaseLiquidity(wethPoolKey, wethAmountMax, supAmountMax);
        } else {
            _mintPosition(wethPoolKey, wethAmountMax, supAmountMax);
        }

        /// TODO / FIXME : here we may want to give away some units in a GDA pool (LP incentives)

        // Transfer the leftover WETH to the caller (if any)
        uint256 leftover = WETH.balanceOf(address(this));
        if (leftover > 0) {
            WETH.transfer(msg.sender, leftover);
        }
    }

    /**
     * @notice Provides liquidity to the USDC/SUP pool
     * @param supAmountMax The maximum amount of SUP to provide as liquidity
     * @param usdcAmountMax The maximum amount of USDC to provide as liquidity
     */
    function provideLiquidityUSDC(uint256 supAmountMax, uint256 usdcAmountMax) external nonReentrant onlyLockerOwner {
        // Transfer USDC from the caller to this locker
        USDC.transferFrom(msg.sender, address(this), usdcAmountMax);

        // Revert if the amount of $FLUID to provide is greater than the available balance
        if (supAmountMax > getAvailableBalance()) {
            /// NOTE / FIXME : here we may want to hard-set the max amount of SUP to getAvailableBalance(). (thoughts?)
            revert INSUFFICIENT_BALANCE();
        }

        /// TODO / FIXME : here we may need to market buy some SUP (pumponomics)

        if (_lockerHasPosition(usdcPoolKey)) {
            _increaseLiquidity(usdcPoolKey, usdcAmountMax, supAmountMax);
        } else {
            _mintPosition(usdcPoolKey, usdcAmountMax, supAmountMax);
        }

        /// TODO / FIXME : here we may want to give away some units in a GDA pool (LP incentives)

        // Transfer the leftover USDC to the caller (if any)
        uint256 leftover = USDC.balanceOf(address(this));
        if (leftover > 0) {
            USDC.transfer(msg.sender, leftover);
        }
    }

    function withdrawLiquidityWETH() external nonReentrant onlyLockerOwner {
        // TODO
    }

    function withdrawLiquidityUSDC() external nonReentrant onlyLockerOwner {
        // TODO
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
        FLUID.distribute(address(this), TAX_DISTRIBUTION_POOL, penaltyAmount);

        // Transfer the leftover $FLUID to the locker owner
        FLUID.transfer(recipient, amountToUnlock - penaltyAmount);

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

    function _lockerHasPosition(PoolKey memory poolKey) internal view returns (bool exists) {
        exists = positonTokenId[poolKey] > 0;
    }

    function _approveTokensWithPermit2(address token0, address token1, uint256 amount0, uint256 amount1) internal {
        // Approve tokens for spending via Permit2
        IERC20(token0).approve(address(PERMIT2), amount0);
        IERC20(token1).approve(address(PERMIT2), amount1);

        IPermit2(PERMIT2).approve(
            token0, address(POSITION_MANAGER), uint160(amount0), uint48(block.timestamp + _LP_OPERATION_DEADLINE)
        );
        IPermit2(PERMIT2).approve(
            token1, address(POSITION_MANAGER), uint160(amount1), uint48(block.timestamp + _LP_OPERATION_DEADLINE)
        );
    }

    function _prepareLiquidityOperation(PoolKey memory poolKey, uint256 pairedAmountMax, uint256 supAmountMax)
        internal
        returns (uint256 liquidity, uint256 amount0Max, uint256 amount1Max)
    {
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);

        if (token0 == address(FLUID)) {
            amount0Max = supAmountMax;
            amount1Max = pairedAmountMax;
        } else {
            amount0Max = pairedAmountMax;
            amount1Max = supAmountMax;
        }

        // Calculate the liquidity based on provided amounts and current price
        (uint160 sqrtPriceX96,,,) = StateLibrary.getSlot0(POOL_MANAGER, PoolIdLibrary.toId(poolKey));

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(TickMath.MIN_TICK),
            TickMath.getSqrtPriceAtTick(TickMath.MAX_TICK),
            amount0Max,
            amount1Max
        );

        // Approve tokens for spending via Permit2
        _approveTokensWithPermit2(token0, token1, amount0Max, amount1Max);
    }

    function _mintPosition(PoolKey memory poolKey, uint256 pairedAmountMax, uint256 supAmountMax) internal {
        (uint256 liquidity, uint256 amount0Max, uint256 amount1Max) =
            _prepareLiquidityOperation(poolKey, pairedAmountMax, supAmountMax);

        // Store the next token ID before minting
        positionTokenId[poolKey] = POSITION_MANAGER.nextTokenId();

        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            poolKey, TickMath.MIN_TICK, TickMath.MAX_TICK, liquidity, amount0Max, amount1Max, address(this), bytes("")
        );
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);

        // Execute the minting transaction
        POSITION_MANAGER.modifyLiquidities(abi.encode(actions, params), block.timestamp + _LP_OPERATION_DEADLINE);
    }

    function _increaseLiquidity(PoolKey memory poolKey, uint256 pairedAmountMax, uint256 supAmountMax) internal {
        (uint256 liquidity, uint256 amount0Max, uint256 amount1Max) =
            _prepareLiquidityOperation(poolKey, pairedAmountMax, supAmountMax);

        bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(positionTokenId[poolKey], liquidity, amount0Max, amount1Max, bytes(""));
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);

        // Execute the liquidity increase transaction
        POSITION_MANAGER.modifyLiquidities(abi.encode(actions, params), block.timestamp + _LP_OPERATION_DEADLINE);
    }

    function _decreaseLiquidity(uint128 liquidity, uint256 amount0min, uint256 amount1min) internal {
        bytes memory actions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(positionTokenId, liquidity, amount0min, amount1min, bytes(""));
        params[1] = abi.encode(currency0, currency1, address(this));

        POSITION_MANAGER.modifyLiquidities(abi.encode(actions, params), block.timestamp + 60);
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
