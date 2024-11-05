// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Staking Reward Controller Contract Interface
 * @author Superfluid
 * @notice Contract responsible for administrating the GDA pool that distribute the unlocking tax to stakers or liquidity providers
 *
 */
interface IStakingRewardController {
    //     ______           __                     ______
    //    / ____/_  _______/ /_____  ____ ___     / ____/_____________  __________
    //   / /   / / / / ___/ __/ __ \/ __ `__ \   / __/ / ___/ ___/ __ \/ ___/ ___/
    //  / /___/ /_/ (__  ) /_/ /_/ / / / / / /  / /___/ /  / /  / /_/ / /  (__  )
    //  \____/\__,_/____/\__/\____/_/ /_/ /_/  /_____/_/  /_/   \____/_/  /____/

    /// @notice Error thrown when the caller is not an approved Locker
    error NOT_APPROVED_LOCKER();

    /// @notice Error thrown when the caller is not the Locker Factory contract
    error NOT_LOCKER_FACTORY();

    /// @notice Error thrown when the caller is not the Program Manager contract
    error NOT_PROGRAM_MANAGER();

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Update the caller's (staker) units within the GDA Penalty Pool
     * @dev Only approved lockers can perform this operation
     * @param lockerStakedBalance locker's new staked balance amount
     */
    function updateStakerUnits(uint256 lockerStakedBalance) external;

    /**
     * @notice Refreshes the subsidy distribution flow rate to the tax distribution pool
     * @dev Only the program manager can perform this operation
     * @param subsidyFlowRate the new subsidy flow rate to be distributed
     */
    function refreshSubsidyDistribution(int96 subsidyFlowRate) external;

    /**
     * @notice Update the Program Manager contract address
     * @dev Only the contract owner can perform this operation
     * @param programManagerAddress Program Manager contract address to be set
     */
    function setProgramManager(address programManagerAddress) external;

    /**
     * @notice Update the Locker Factory contract address
     * @dev Only the contract owner can perform this operation
     * @param lockerFactoryAddress Locker Factory contract address to be set
     */
    function setLockerFactory(address lockerFactoryAddress) external;

    /**
     * @notice Approve a Locker to interact with the Staking Reward Controller contract
     * @dev Only the Locker Factory contract can perform this operation
     * @param lockerAddress Locker contract address to be approved
     */
    function approveLocker(address lockerAddress) external;
}
