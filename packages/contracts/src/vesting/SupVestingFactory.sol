// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";
import { SupVesting } from "src/vesting/SupVesting.sol";

using SuperTokenV1Library for ISuperToken;

contract SupVestingFactory {
    IVestingSchedulerV2 public immutable VESTING_SCHEDULER;
    ISuperToken public immutable SUP;
    address public immutable TREASURY;

    mapping(address recipient => address supVesting) public supVestings;

    constructor(IVestingSchedulerV2 vestingScheduler, ISuperToken token, address treasury) {
        // Persist immutable addresses
        VESTING_SCHEDULER = vestingScheduler;
        SUP = token;
        TREASURY = treasury;
    }

    function balanceOf(address vestingReceiver) public view returns (uint256) {
        return SUP.balanceOf(supVestings[vestingReceiver]);
    }

    function createSupVestingContract(
        address recipient,
        uint256 amount,
        uint32 duration,
        uint32 startDate,
        uint32 cliffPeriod
    ) external returns (address newSupVestingContract) {
        newSupVestingContract = address(
            new SupVesting(VESTING_SCHEDULER, SUP, TREASURY, recipient, amount, duration, startDate, cliffPeriod)
        );

        supVestings[recipient] = newSupVestingContract;
    }
}
