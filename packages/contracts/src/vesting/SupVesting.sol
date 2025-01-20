// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";

using SuperTokenV1Library for ISuperToken;

contract SupVesting {
    // Foundation Treasury address
    address public immutable TREASURY;

    // Recipient address
    address public immutable RECIPIENT;

    // Superfluid Vesting Scheduler contract address
    IVestingSchedulerV2 public immutable VESTING_SCHEDULER;

    // SUP Token contract address
    ISuperToken public immutable SUP;

    // Error thrown when the caller is not the foundation treasury
    error FORBIDDEN();

    constructor(
        IVestingSchedulerV2 vestingScheduler,
        ISuperToken token,
        address treasury,
        address recipient,
        uint256 amount,
        uint32 duration,
        uint32 startDate,
        uint32 cliffPeriod
    ) {
        // Persist the admin, recipient, and vesting scheduler addresses
        TREASURY = treasury;
        RECIPIENT = recipient;
        VESTING_SCHEDULER = vestingScheduler;
        SUP = token;

        // Grant flow and token allowances
        token.setMaxFlowPermissions(address(vestingScheduler));
        token.approve(address(vestingScheduler), type(uint256).max);

        // Create the vesting schedule for this recipient
        vestingScheduler.createVestingScheduleFromAmountAndDuration(
            token, recipient, amount, duration, startDate, cliffPeriod, 0 /* claimPeriod */
        );
    }

    function cancelVesting() external onlyFoundation {
        // Delete the vesting schedule
        VESTING_SCHEDULER.deleteVestingSchedule(SUP, RECIPIENT, bytes(""));

        // Transfer the remaining SUP tokens to the treasury
        SUP.transfer(TREASURY, SUP.balanceOf(address(this)));
    }

    modifier onlyFoundation() {
        if (msg.sender != TREASURY) revert FORBIDDEN();
        _;
    }
}
