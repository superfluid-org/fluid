// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { Ownable } from "@openzeppelin-v5/contracts/access/Ownable.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperfluidPool,
    ISuperToken,
    PoolConfig
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Interfaces */
import { IPenaltyManager } from "./interfaces/IPenaltyManager.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title Penalty Manager Contract
 * @author Superfluid
 * @notice Contract responsible for administrating the GDA pool that distribute the unlocking tax to stakers or liquidity providers
 *
 */
contract PenaltyManager is Ownable, IPenaltyManager {
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable TAX_DISTRIBUTION_POOL;

    /// @notice Value used to convert staked amount into GDA pool units
    uint128 private constant _UNIT_DOWNSCALER = 1e16;

    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice Locker Factory contract address
    address public lockerFactory;

    /// @notice Fluid Program Manager contract address
    address public programManager;

    /// @notice Stores the approval status of a given locker contract address
    mapping(address locker => bool isApproved) private _approvedLockers;

    uint256 public subsidyRate;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Penalty Manager contract constructor
     * @param owner Penalty Manager contract owner address
     * @param fluid FLUID SuperToken contract interface
     */
    constructor(address owner, ISuperToken fluid) Ownable(owner) {
        FLUID = fluid;

        // Configure Superfluid GDA Pool
        PoolConfig memory poolConfig =
            PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: true });

        // Create Superfluid GDA Pool
        TAX_DISTRIBUTION_POOL = fluid.createPool(address(this), poolConfig);
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IPenaltyManager
    function updateStakerUnits(uint256 lockerStakedBalance) external onlyApprovedLocker {
        /// FIXME Define proper stakedBalance to GDA pool units calculation
        FLUID.updateMemberUnits(TAX_DISTRIBUTION_POOL, msg.sender, uint128(lockerStakedBalance) / _UNIT_DOWNSCALER);
    }

    /// @inheritdoc IPenaltyManager
    function refreshSubsidyDistribution(int96 subsidyFlowRate) external onlyProgramManager {
        FLUID.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, subsidyFlowRate);
    }

    /// @inheritdoc IPenaltyManager
    function setLockerFactory(address lockerFactoryAddress) external onlyOwner {
        lockerFactory = lockerFactoryAddress;
    }

    /// @inheritdoc IPenaltyManager
    function setProgramManager(address programManagerAddress) external onlyOwner {
        programManager = programManagerAddress;
    }

    /// @inheritdoc IPenaltyManager
    function approveLocker(address lockerAddress) external onlyLockerFactory {
        _approvedLockers[lockerAddress] = true;
    }

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @dev Throws if called by any account other than the Locker Factory contract
     */
    modifier onlyLockerFactory() {
        if (msg.sender != lockerFactory) revert NOT_LOCKER_FACTORY();
        _;
    }

    modifier onlyProgramManager() {
        if (msg.sender != programManager) revert NOT_PROGRAM_MANAGER();
        _;
    }

    modifier onlyApprovedLocker() {
        if (!_approvedLockers[msg.sender]) revert NOT_APPROVED_LOCKER();
        _;
    }
}
