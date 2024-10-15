// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { Math } from "@openzeppelin-v5/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";
import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Interfaces */
import { IEPProgramManager } from "./interfaces/IEPProgramManager.sol";
import { IFluidLocker } from "./interfaces/IFluidLocker.sol";
import { IPenaltyManager } from "./interfaces/IPenaltyManager.sol";
import { IFontaine } from "./interfaces/IFontaine.sol";

using SuperTokenV1Library for ISuperToken;
using SafeCast for int256;

/**
 * @title Locker Contract
 * @author Superfluid
 * @notice Contract responsible for locking and holding FLUID token on behalf of users
 *
 */
contract FluidLocker is Initializable, IFluidLocker {
    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// FIXME storage packing

    /// @notice FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid GDA pool interface
    ISuperfluidPool public immutable PENALTY_DRAINING_POOL;

    /// @notice Distribution Program Manager interface
    IEPProgramManager public immutable EP_PROGRAM_MANAGER;

    /// @notice Penalty Manager interface
    IPenaltyManager public immutable PENALTY_MANAGER;

    /// @notice Connected Fontaine interface
    IFontaine public fontaine;

    /// @notice This locker owner address
    address public lockerOwner;

    /// @notice Timestamp at which the staking cooldown period is elapsed
    uint128 public stakingUnlocksAt;

    /// @notice Staking cooldown period
    /// FIXME Discuss arbitrary decision
    uint128 private constant _STAKING_COOLDOWN_PERIOD = 3 days;

    /// @notice Minimum drain period allowed
    /// FIXME Discuss arbitrary decision
    uint128 private constant _MIN_DRAIN_PERIOD = 7 days;

    /// @notice Maximum drain period allowed
    /// FIXME Discuss arbitrary decision
    uint128 private constant _MAX_DRAIN_PERIOD = 540 days;

    /// @notice Instant drain penalty percentage (expressed in basis points)
    /// FIXME Discuss arbitrary decision
    uint256 private constant _INSTANT_DRAIN_PENALTY_BP = 8_000;

    /// @notice Basis points denominator (for percentage calculation)
    uint256 private constant _BP_DENOMINATOR = 10_000;

    /// @notice Scaler used for drain percentage calculation
    uint256 private constant _SCALER = 1e18;

    /// @notice Scaler used for drain percentage calculation
    uint256 private constant _PERCENT_TO_BP = 100;

    /// @notice Balance of $FLUID token staked in this locker
    uint256 private _stakedBalance;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Locker contract constructor
     * @param fluid FLUID SuperToken contract interface
     * @param penaltyDrainingPool Penalty Draining Pool GDA contract interface
     * @param programManager Ecosystem Partner Program Manager contract interface
     */
    constructor(ISuperToken fluid, ISuperfluidPool penaltyDrainingPool, IEPProgramManager programManager) {
        // Disable initializers to prevent implementation contract initalization
        _disableInitializers();

        // Sets immutable states
        FLUID = fluid;
        PENALTY_DRAINING_POOL = penaltyDrainingPool;
        EP_PROGRAM_MANAGER = programManager;
    }

    /**
     * @notice Locker contract initializer
     * @param owner this Locker contract owner account
     * @param fontaineAddress Fontaine contract address connected to this Locker
     */
    function initialize(address owner, address fontaineAddress) external initializer {
        // Sets the owner of this locker
        lockerOwner = owner;

        // Sets the Fontaine contract associated to this Locker
        fontaine = IFontaine(fontaineAddress);
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLocker
    function claim(uint96 programId, uint128 totalProgramUnits, uint256 nonce, bytes memory stackSignature) external {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        if (!FLUID.isMemberConnected(address(programPool), address(this))) {
            // Connect this locker to the Program Pool
            FLUID.connectPool(programPool);
        }

        EP_PROGRAM_MANAGER.updateUnits(programId, totalProgramUnits, nonce, stackSignature);
    }

    /// @inheritdoc IFluidLocker
    function claim(
        uint96[] memory programIds,
        uint128[] memory totalProgramUnits,
        uint256[] memory nonces,
        bytes[] memory stackSignatures
    ) external {
        for (uint256 i = 0; i < programIds.length; ++i) {
            // Get the corresponding program pool
            ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programIds[i]);

            if (!FLUID.isMemberConnected(address(programPool), address(this))) {
                // Connect this locker to the Program Pool
                FLUID.connectPool(programPool);
            }
        }

        EP_PROGRAM_MANAGER.updateUnits(programIds, totalProgramUnits, nonces, stackSignatures);
    }

    /// @inheritdoc IFluidLocker
    function lock(uint256 amount) external {
        // Fetch the amount of FLUID Token to be locked from the caller
        FLUID.transferFrom(msg.sender, address(this), amount);

        /// FIXME emit `FLUID locked` event
    }

    /// @inheritdoc IFluidLocker
    function drain(uint128 drainPeriod) external onlyOwner {
        // Enforce drain period validity
        if (drainPeriod != 0 && (drainPeriod < _MIN_DRAIN_PERIOD || drainPeriod > _MAX_DRAIN_PERIOD)) {
            revert INVALID_DRAIN_PERIOD();
        }

        // Get balance available for draining
        uint256 availableBalance = getAvailableBalance();

        // Revert if there is no FLUID to drain
        if (availableBalance == 0) revert NO_FLUID_TO_DRAIN();

        if (drainPeriod == 0) {
            _instantDrain(availableBalance);
        } else {
            _vestDrain(availableBalance, drainPeriod);
        }

        /// FIXME emit `drained locker` event
    }

    /// @inheritdoc IFluidLocker
    function stake() external onlyOwner {
        uint256 amountToStake = getAvailableBalance();

        if (amountToStake == 0) revert NO_FLUID_TO_STAKE();

        if (!FLUID.isMemberConnected(address(PENALTY_DRAINING_POOL), address(this))) {
            // Connect this locker to the Penalty Draining Pool
            FLUID.connectPool(PENALTY_DRAINING_POOL);
        }

        // Update staked balance
        _stakedBalance += amountToStake;

        // Update unlock timestamp
        stakingUnlocksAt = uint128(block.timestamp) + _STAKING_COOLDOWN_PERIOD;

        // Call Penalty Manager to update staker's units
        PENALTY_MANAGER.updateStakerUnits(_stakedBalance);

        /// FIXME emit `staked` event
    }

    /// @inheritdoc IFluidLocker
    function unstake() external onlyOwner {
        if (block.timestamp < stakingUnlocksAt) {
            revert STAKING_COOLDOWN_NOT_ELAPSED();
        }

        // Enfore staked balance is not zero
        if (_stakedBalance == 0) revert NO_FLUID_TO_UNSTAKE();

        // Set staked balance to 0
        _stakedBalance = 0;

        // Call Penalty Manager to update staker's units
        PENALTY_MANAGER.updateStakerUnits(0);

        // Disconnect this locker from the Penalty Draining Pool
        FLUID.disconnectPool(PENALTY_DRAINING_POOL);

        /// FIXME emit `unstaked` event
    }

    /// @inheritdoc IFluidLocker
    function transferLocker(address recipient) external onlyOwner {
        if (recipient == address(0)) revert FORBIDDEN();
        lockerOwner = recipient;

        /// FIXME emit `ownership transferred` event
    }

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLocker
    function getFlowRatePerProgram(uint96 programId) external view returns (int96 flowRate) {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        // Get the flow rate
        flowRate = FLUID.getFlowRate(address(programPool), address(this));
    }

    /// @inheritdoc IFluidLocker
    function getFlowRatePerProgram(uint96[] memory programIds) external view returns (int96[] memory flowRates) {
        flowRates = new int96[](programIds.length);

        for (uint256 i = 0; i < programIds.length; ++i) {
            // Get the corresponding program pool
            ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programIds[i]);

            // Get the flow rate
            flowRates[i] = FLUID.getFlowRate(address(programPool), address(this));
        }
    }

    /// @inheritdoc IFluidLocker
    function getUnitsPerProgram(uint96 programId) external view returns (uint128 units) {
        // Get the corresponding program pool
        ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programId);

        // Get this locker's unit within the given program identifier
        units = programPool.getUnits(address(this));
    }

    /// @inheritdoc IFluidLocker
    function getUnitsPerProgram(uint96[] memory programIds) external view returns (uint128[] memory units) {
        units = new uint128[](programIds.length);

        for (uint256 i = 0; i < programIds.length; ++i) {
            // Get the corresponding program pool
            ISuperfluidPool programPool = EP_PROGRAM_MANAGER.getProgramPool(programIds[i]);

            // Get the flow rate
            units[i] = programPool.getUnits(address(this));
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

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    function _instantDrain(uint256 amountToDrain) internal {
        // Calculate instant drain penalty amount
        uint256 penaltyAmount = (amountToDrain * _INSTANT_DRAIN_PENALTY_BP) / _BP_DENOMINATOR;

        // Distribute penalty to staker (connected to the PENALTY_DRAINING_POOL)
        FLUID.distributeToPool(address(this), PENALTY_DRAINING_POOL, penaltyAmount);

        // Transfer the leftover $FLUID to the locker owner
        FLUID.transfer(msg.sender, amountToDrain - penaltyAmount);
    }

    function _vestDrain(uint256 amountToDrain, uint128 drainPeriod) internal {
        // Calculate the drain and penalty flow rates based on requested amount and drain period
        (int96 drainFlowRate, int96 penaltyFlowRate) = _calculateVestDrainFlowRates(amountToDrain, drainPeriod);

        // Transfer the total amount to drain to the connected Fontaine
        FLUID.transfer(address(fontaine), amountToDrain);

        // Initiate drain process
        fontaine.processDrain(lockerOwner, drainFlowRate, penaltyFlowRate);
    }

    function _calculateVestDrainFlowRates(uint256 amountToDrain, uint128 drainPeriod)
        internal
        pure
        returns (int96 drainFlowRate, int96 penaltyFlowRate)
    {
        uint256 amountToUser = (amountToDrain * _getDrainPercentage(drainPeriod)) / _BP_DENOMINATOR;
        uint256 penaltyAmount = amountToDrain - amountToUser;

        drainFlowRate = int256(amountToUser / drainPeriod).toInt96();
        penaltyFlowRate = int256(penaltyAmount / drainPeriod).toInt96();
    }

    function _getDrainPercentage(uint128 drainPeriod) internal pure returns (uint256 drainPercentageBP) {
        drainPercentageBP = (
            _PERCENT_TO_BP
                * (
                    ((80 * _SCALER) / Math.sqrt(540 * _SCALER)) * (Math.sqrt(drainPeriod * _SCALER) / _SCALER)
                        + 20 * _SCALER
                )
        ) / _SCALER;
    }

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @dev Throws if called by any account other than the owner
     */
    modifier onlyOwner() {
        if (msg.sender != lockerOwner) revert NOT_LOCKER_OWNER();
        _;
    }
}
