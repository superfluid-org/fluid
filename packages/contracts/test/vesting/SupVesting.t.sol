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

    uint256 public constant VESTING_AMOUNT = 1000 ether;
    uint256 public constant CLIFF_AMOUNT = 333 ether;

    uint32 public constant VESTING_DURATION = 730 days;
    uint32 public constant CLIFF_PERIOD = 365 days;

    uint32 public cliffDate;
    int96 public flowRate;
    uint256 public remainder;

    function setUp() public virtual override {
        super.setUp();

        vestingScheduler = new VestingSchedulerV2(_sf.host);
        supVestingFactory = new SupVestingFactory(
            IVestingSchedulerV2(address(vestingScheduler)), ISuperToken(_fluidSuperToken), FLUID_TREASURY, ADMIN
        );

        // Move time forward to avoid vesting scheduler errors (time based input validation constraints)
        vm.warp(block.timestamp + 420 days);

        vm.prank(FLUID_TREASURY);
        _fluidSuperToken.approve(address(supVestingFactory), VESTING_AMOUNT * 1000);

        cliffDate = uint32(block.timestamp + CLIFF_PERIOD);
        flowRate = int256((VESTING_AMOUNT - CLIFF_AMOUNT) / uint256(VESTING_DURATION)).toInt96();

        remainder = VESTING_AMOUNT - CLIFF_AMOUNT - (SafeCast.toUint256(flowRate) * VESTING_DURATION);

        vm.prank(ADMIN);
        supVestingFactory.createSupVestingContract(
            ALICE, VESTING_AMOUNT, cliffDate, flowRate, CLIFF_AMOUNT, uint32(cliffDate + VESTING_DURATION)
        );

        supVesting = SupVesting(address(supVestingFactory.supVestings(ALICE)));
    }

    function testVesting() public {
        // Move time to after vesting can be started
        vm.warp(cliffDate);

        // Execute the vesting start
        vestingScheduler.executeCliffAndFlow(_fluidSuperToken, address(supVesting), ALICE);

        assertEq(_fluidSuperToken.balanceOf(ALICE), CLIFF_AMOUNT, "Alice should have received the cliff amount");
        assertEq(_fluidSuperToken.getFlowRate(address(supVesting), ALICE), flowRate, "Flow rate mismatch");

        IVestingSchedulerV2.VestingSchedule memory aliceVS =
            vestingScheduler.getVestingSchedule(address(_fluidSuperToken), address(supVesting), ALICE);

        // Move time to after vesting can be concluded (1 seconds before the stream gets in critical state)
        vm.warp(aliceVS.endDate - 5 hours - 1 seconds);

        vestingScheduler.executeEndVesting(_fluidSuperToken, address(supVesting), ALICE);

        // assertEq(_fluidSuperToken.balanceOf(ALICE), VESTING_AMOUNT, "Alice should have the full amount");
        assertEq(_fluidSuperToken.balanceOf(address(supVesting)), remainder, "SupVesting contract should be empty");
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
        vm.warp(cliffDate + 1 minutes);

        // Execute the vesting start
        vestingScheduler.executeCliffAndFlow(_fluidSuperToken, address(supVesting), ALICE);

        int96 vestingFlowRate = _fluidSuperToken.getFlowRate(address(supVesting), ALICE);

        console2.log("vestingFlowRate", vestingFlowRate);

        assertEq(vestingFlowRate, flowRate, "Flow rate mismatch");

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
