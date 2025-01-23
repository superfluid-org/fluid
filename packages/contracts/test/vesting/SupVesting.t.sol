// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { SFTest } from "../SFTest.t.sol";
import { ISupVestingFactory, SupVestingFactory } from "src/vesting/SupVestingFactory.sol";
import { SupVesting } from "src/vesting/SupVesting.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import { VestingSchedulerV2 } from "@superfluid-finance/automation-contracts/scheduler/contracts/VestingSchedulerV2.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";

contract SupVestingTest is SFTest {
    SupVestingFactory public supVestingFactory;
    SupVesting public supVesting;
    VestingSchedulerV2 public vestingScheduler;

    uint32 public constant VESTING_DURATION = 365 days;
    uint32 public constant CLIFF_PERIOD = 0;

    function setUp() public virtual override {
        super.setUp();

        vestingScheduler = new VestingSchedulerV2(_sf.host);
        supVestingFactory = new SupVestingFactory(
            IVestingSchedulerV2(address(vestingScheduler)), ISuperToken(_fluidSuperToken), FLUID_TREASURY, ADMIN
        );

        // Move time forward to avoid vesting scheduler errors (time based input validation constraints)
        vm.warp(block.timestamp + 420 days);

        vm.prank(FLUID_TREASURY);
        _fluidSuperToken.approve(address(supVestingFactory), 100_000 ether);

        vm.prank(ADMIN);
        supVestingFactory.createSupVestingContract(
            ALICE, 100_000 ether, VESTING_DURATION, uint32(block.timestamp + 365 days), CLIFF_PERIOD, true
        );

        supVesting = SupVesting(address(supVestingFactory.supVestings(ALICE)));
    }
}
