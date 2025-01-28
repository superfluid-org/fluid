// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console2 } from "forge-std/Test.sol";
import { SFTest } from "../SFTest.t.sol";
import { SupVestingFactory } from "src/vesting/SupVestingFactory.sol";
import { ISupVesting, SupVesting } from "src/vesting/SupVesting.sol";
import { ISuperToken, SuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import { VestingSchedulerV2 } from "@superfluid-finance/automation-contracts/scheduler/contracts/VestingSchedulerV2.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";

using SuperTokenV1Library for SuperToken;
using SafeCast for int256;

contract SupVestingTest is SFTest {
    SupVestingFactory public supVestingFactory;
    SupVesting public supVesting;
    VestingSchedulerV2 public vestingScheduler;

    uint256 public constant VESTING_AMOUNT = 100_000 ether;
    uint32 public constant VESTING_DURATION = 1095 days;
    uint32 public constant CLIFF_PERIOD = 365 days;

    function setUp() public virtual override {
        super.setUp();

        vestingScheduler = new VestingSchedulerV2(_sf.host);
        supVestingFactory = new SupVestingFactory(
            IVestingSchedulerV2(address(vestingScheduler)), ISuperToken(_fluidSuperToken), FLUID_TREASURY, ADMIN
        );

        // Move time forward to avoid vesting scheduler errors (time based input validation constraints)
        vm.warp(block.timestamp + 420 days);

        vm.prank(FLUID_TREASURY);
        _fluidSuperToken.approve(address(supVestingFactory), VESTING_AMOUNT);

        vm.prank(ADMIN);
        supVestingFactory.createSupVestingContract(
            ALICE, VESTING_AMOUNT, VESTING_DURATION, uint32(block.timestamp), CLIFF_PERIOD
        );

        supVesting = SupVesting(address(supVestingFactory.supVestings(ALICE)));
    }

    function testVesting() public {
        // Move time to after vesting can be started
        vm.warp(block.timestamp + 365 days + 1 seconds);

        int96 expectedFlowRate = int256(VESTING_AMOUNT / uint256(VESTING_DURATION)).toInt96();

        // Execute the vesting start
        vestingScheduler.executeCliffAndFlow(_fluidSuperToken, address(supVesting), ALICE);

        assertApproxEqAbs(
            _fluidSuperToken.getFlowRate(address(supVesting), ALICE),
            expectedFlowRate,
            uint256((int256(expectedFlowRate) * 10) / 10_000),
            "Flow rate mismatch"
        );

        IVestingSchedulerV2.VestingSchedule memory aliceVS =
            vestingScheduler.getVestingSchedule(address(_fluidSuperToken), address(supVesting), ALICE);

        // Move time to after vesting can be concluded (1 seconds before the stream gets in critical state)
        vm.warp(aliceVS.endDate - 4 hours - 1 seconds);

        vestingScheduler.executeEndVesting(_fluidSuperToken, address(supVesting), ALICE);

        assertEq(_fluidSuperToken.balanceOf(ALICE), VESTING_AMOUNT, "Alice should have the full amount");
        assertEq(_fluidSuperToken.balanceOf(address(supVesting)), 0, "SupVesting contract should be empty");
    }

    function testEmergencyWithdrawBeforeVestingStart(address nonAdmin) public {
        vm.assume(nonAdmin != address(ADMIN));

        vm.prank(nonAdmin);
        vm.expectRevert(ISupVesting.FORBIDDEN.selector);
        supVesting.emergencyWithdraw();

        uint256 treasuryBalanceBefore = _fluidSuperToken.balanceOf(FLUID_TREASURY);
        uint256 aliceVestingBalanceBefore = _fluidSuperToken.balanceOf(address(supVesting));

        vm.prank(ADMIN);
        supVesting.emergencyWithdraw();

        assertEq(
            _fluidSuperToken.balanceOf(FLUID_TREASURY),
            treasuryBalanceBefore + aliceVestingBalanceBefore,
            "Balance should be updated"
        );

        assertEq(_fluidSuperToken.balanceOf(address(supVesting)), 0, "Balance should be 0");
    }

    function testEmergencyWithdrawAfterVestingStart(address nonAdmin) public {
        vm.assume(nonAdmin != address(ADMIN));

        vm.prank(nonAdmin);
        vm.expectRevert(ISupVesting.FORBIDDEN.selector);
        supVesting.emergencyWithdraw();

        // Move time to after vesting can be started
        vm.warp(block.timestamp + CLIFF_PERIOD + 1 days);

        // Execute the vesting start
        vestingScheduler.executeCliffAndFlow(_fluidSuperToken, address(supVesting), ALICE);

        int96 vestingFlowRate = _fluidSuperToken.getFlowRate(address(supVesting), ALICE);
        int96 expectedFlowRate = int256(VESTING_AMOUNT / uint256(VESTING_DURATION)).toInt96();

        console2.log("vestingFlowRate", vestingFlowRate);

        assertEq(vestingFlowRate, expectedFlowRate, "Flow rate mismatch");

        vm.warp(block.timestamp + 5 days);

        uint256 treasuryBalanceBefore = _fluidSuperToken.balanceOf(FLUID_TREASURY);
        uint256 aliceVestingBalanceBefore = _fluidSuperToken.balanceOf(address(supVesting));

        vm.prank(ADMIN);
        supVesting.emergencyWithdraw();

        assertEq(_fluidSuperToken.getFlowRate(address(supVesting), ALICE), 0, "Flow should be deleted");

        assertApproxEqAbs(
            _fluidSuperToken.balanceOf(FLUID_TREASURY),
            treasuryBalanceBefore + aliceVestingBalanceBefore,
            (_fluidSuperToken.balanceOf(FLUID_TREASURY) * 10) / 10_000, // 0.1% tolerance
            "Balance should be updated"
        );

        assertEq(_fluidSuperToken.balanceOf(address(supVesting)), 0, "Balance should be 0");
    }
}
