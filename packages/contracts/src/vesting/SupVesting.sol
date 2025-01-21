// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";

using SuperTokenV1Library for ISuperToken;

interface ISupVestingFactory {
    function balanceOf(address vestingReceiver) external view returns (uint256);

    function createSupVestingContract(
        address recipient,
        uint256 amount,
        uint32 duration,
        uint32 startDate,
        uint32 cliffPeriod
    ) external returns (address newSupVestingContract);

    function setTreasury(address newTreasury) external;

    function setAdmin(address newAdmin) external;

    function admin() external view returns (address);
    function treasury() external view returns (address);
}

contract SupVesting {
    // Factory Address
    ISupVestingFactory public immutable FACTORY;

    // Recipient address
    address public immutable RECIPIENT;

    // Superfluid Vesting Scheduler contract address
    IVestingSchedulerV2 public immutable VESTING_SCHEDULER;

    // SUP Token contract address
    ISuperToken public immutable SUP;

    // Error thrown when the caller is not the foundation treasury
    error FORBIDDEN();

    /**
     * @notice SupVesting contract constructor
     * @param vestingScheduler The Superfluid vesting scheduler contract
     * @param token The SUP token contract
     * @param recipient The recipient of the vested tokens
     * @param amount The total amount of tokens to vest
     * @param duration The duration of the vesting schedule in seconds
     * @param startDate The timestamp when vesting begins
     * @param cliffPeriod The cliff period in seconds before any tokens vest
     */
    constructor(
        IVestingSchedulerV2 vestingScheduler,
        ISuperToken token,
        address recipient,
        uint256 amount,
        uint32 duration,
        uint32 startDate,
        uint32 cliffPeriod
    ) {
        // Persist the admin, recipient, and vesting scheduler addresses
        RECIPIENT = recipient;
        VESTING_SCHEDULER = vestingScheduler;
        SUP = token;
        FACTORY = ISupVestingFactory(msg.sender);

        // Grant flow and token allowances
        token.setMaxFlowPermissions(address(vestingScheduler));
        token.approve(address(vestingScheduler), type(uint256).max);

        // Create the vesting schedule for this recipient
        vestingScheduler.createVestingScheduleFromAmountAndDuration(
            token, recipient, amount, duration, startDate, cliffPeriod, 0 /* claimPeriod */
        );
    }

    function emergencyWithdraw() external onlyFoundation {
        // Delete the vesting schedule
        VESTING_SCHEDULER.deleteVestingSchedule(SUP, RECIPIENT, bytes(""));

        // Transfer the remaining SUP tokens to the treasury
        SUP.transfer(FACTORY.treasury(), SUP.balanceOf(address(this)));
    }

    modifier onlyFoundation() {
        if (msg.sender != FACTORY.admin()) revert FORBIDDEN();
        _;
    }
}
