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

contract SupVestingTestInit is SFTest {
    SupVestingFactory public supVestingFactory;
    VestingSchedulerV2 public vestingScheduler;

    function setUp() public virtual override {
        super.setUp();

        vestingScheduler = new VestingSchedulerV2(_sf.host);
        supVestingFactory = new SupVestingFactory(
            IVestingSchedulerV2(address(vestingScheduler)), ISuperToken(_fluidSuperToken), FLUID_TREASURY, ADMIN
        );
    }
}

contract SupVestingTest is SupVestingTestInit {
    SupVesting public supVesting;

    uint256 public constant VESTING_AMOUNT = 115340 ether;
    uint256 public constant CLIFF_AMOUNT = 38446666666666717280000;

    uint32 public constant VESTING_DURATION = 730 days;
    uint32 public constant CLIFF_PERIOD = 365 days;

    uint32 public cliffDate;
    int96 public flowRate;

    function setUp() public virtual override {
        super.setUp();

        // Move time forward to avoid vesting scheduler errors (time based input validation constraints)
        vm.warp(block.timestamp + 420 days);

        vm.prank(FLUID_TREASURY);
        _fluidSuperToken.approve(address(supVestingFactory), VESTING_AMOUNT * 1000);

        cliffDate = uint32(block.timestamp + CLIFF_PERIOD);
        flowRate = int256((VESTING_AMOUNT - CLIFF_AMOUNT) / uint256(VESTING_DURATION)).toInt96();

        vm.prank(ADMIN);
        supVestingFactory.createSupVestingContract(
            ALICE, VESTING_AMOUNT, cliffDate, uint32(cliffDate + VESTING_DURATION)
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

/// @notice This test is meant to be updated with all the real data for each insider
contract SupVestingTestRealData is SupVestingTestInit {
    uint32 public constant TWO_YEARS_IN_SECONDS = 63072000;

    uint256 public constant CURRENT_DATE = 1740783600; // March 1st 2025 (CET)
    uint32 public constant CLIFF_DATE = 1772319600; // March 1st 2026 (CET)
    uint32 public constant END_DATE = CLIFF_DATE + TWO_YEARS_IN_SECONDS; // Feb 29th 2028 00:00:00 (CET)

    uint256 public constant TOTAL_MAX_VESTING_AMOUNT = 250_000_000 ether;

    uint256[7] public amounts;
    uint256[7] public expectedCliffAmounts;
    int96[7] public expectedFlowRates;

    function setUp() public virtual override {
        super.setUp();

        amounts = [100_000 ether, 50_000 ether, 25_000 ether, 17_500 ether, 14_000 ether, 12_710 ether, 9_850 ether];

        expectedCliffAmounts = [
            33333333333333347008000,
            16666666666666673504000,
            8333333333333368288000,
            5833333333333338880000,
            4666666666666671104000,
            4236666666666685472000,
            3283333333333358080000
        ];

        expectedFlowRates = [
            int96(1056993066125486),
            int96(528496533062743),
            int96(264248266531371),
            int96(184973786571960),
            int96(147979029257568),
            int96(134343818704549),
            int96(104113817013360)
        ];

        vm.prank(FLUID_TREASURY);
        _fluidSuperToken.approve(address(supVestingFactory), TOTAL_MAX_VESTING_AMOUNT);
    }

    function testVestings(uint256 creationDate) public {
        creationDate = bound(creationDate, CURRENT_DATE, CLIFF_DATE - 3 days);
        vm.warp(creationDate);
        _helperCreateVestings();

        vm.warp(CLIFF_DATE);
        _helperExecuteCliffAndFlow();

        vm.warp(END_DATE - 24 hours);
        _helperExecuteEndVestings();
    }

    function _helperCreateVestings() internal {
        vm.startPrank(ADMIN);

        for (uint256 i = 0; i < amounts.length; i++) {
            supVestingFactory.createSupVestingContract(vm.addr(i + 69_420), amounts[i], CLIFF_DATE, END_DATE);
        }

        vm.stopPrank();
    }

    function _helperExecuteCliffAndFlow() internal {
        vm.startPrank(ADMIN);

        for (uint256 i = 0; i < amounts.length; i++) {
            address recipient = vm.addr(i + 69_420);
            address sv = address(supVestingFactory.supVestings(recipient));

            vestingScheduler.executeCliffAndFlow(_fluidSuperToken, sv, recipient);

            assertEq(
                _fluidSuperToken.balanceOf(recipient),
                expectedCliffAmounts[i],
                "recipient should have received the exact cliff amount"
            );
            assertEq(_fluidSuperToken.getFlowRate(sv, recipient), expectedFlowRates[i], "Recipient Flow rate mismatch");
        }

        vm.stopPrank();
    }

    function _helperExecuteEndVestings() internal {
        vm.startPrank(ADMIN);

        for (uint256 i = 0; i < amounts.length; i++) {
            address recipient = vm.addr(i + 69_420);
            address sv = address(supVestingFactory.supVestings(recipient));

            console2.log("amounts[i]", amounts[i]);
            vestingScheduler.executeEndVesting(_fluidSuperToken, sv, recipient);

            assertEq(
                _fluidSuperToken.balanceOf(recipient), amounts[i], "Recipient should have received the full amount"
            );
            assertEq(_fluidSuperToken.balanceOf(sv), 0, "SupVesting contract should be empty");
            assertEq(_fluidSuperToken.getFlowRate(sv, recipient), 0, "Recipient Flow rate should be 0");
        }

        vm.stopPrank();
    }
}
