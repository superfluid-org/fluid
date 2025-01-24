// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";
import { console2 } from "forge-std/Test.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { StakingRewardController, IStakingRewardController } from "../src/StakingRewardController.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";

using SuperTokenV1Library for ISuperToken;
using SafeCast for int256;

contract StakingRewardControllerTest is SFTest {
    // Units downscaler defined in StakingRewardController.sol
    uint128 private constant _UNIT_DOWNSCALER = 1e16;

    function setUp() public override {
        super.setUp();
    }

    function testUpdateStakerUnitsWithoutSubsidy(address caller, uint256 stakingAmount) external {
        vm.assume(caller != address(0));
        vm.assume(caller != address(_stakingRewardController.taxDistributionPool()));
        stakingAmount = bound(stakingAmount, 1e16, 10_000_000e18);

        vm.prank(caller);
        vm.expectRevert(IStakingRewardController.NOT_APPROVED_LOCKER.selector);
        _stakingRewardController.updateStakerUnits(stakingAmount);

        vm.expectRevert(IStakingRewardController.NOT_LOCKER_FACTORY.selector);
        _stakingRewardController.approveLocker(caller);

        vm.prank(address(_fluidLockerFactory));
        _stakingRewardController.approveLocker(caller);

        vm.prank(caller);
        _stakingRewardController.updateStakerUnits(stakingAmount);

        assertEq(
            _stakingRewardController.taxDistributionPool().getUnits(caller),
            stakingAmount / _UNIT_DOWNSCALER,
            "incorrect amount of units"
        );
    }

    function testUpdateStakerUnitsWithSubsidy(address caller, uint256 stakingAmount, uint96 subsidyRate) external {
        vm.assume(caller != address(0));
        vm.assume(caller != address(_stakingRewardController.taxDistributionPool()));
        stakingAmount = bound(stakingAmount, 1 ether, 10_000_000 ether);
        subsidyRate = uint96(bound(subsidyRate, 10, 9_900));

        // Pre-fund the staking reward controller for subsidy yield
        vm.prank(FLUID_TREASURY);
        _fluid.transfer(address(_stakingRewardController), 10_000_000 ether);

        vm.prank(ADMIN);
        _stakingRewardController.setSubsidyRate(subsidyRate);

        vm.prank(caller);
        vm.expectRevert(IStakingRewardController.NOT_APPROVED_LOCKER.selector);
        _stakingRewardController.updateStakerUnits(stakingAmount);

        vm.expectRevert(IStakingRewardController.NOT_LOCKER_FACTORY.selector);
        _stakingRewardController.approveLocker(caller);

        vm.prank(address(_fluidLockerFactory));
        _stakingRewardController.approveLocker(caller);

        vm.startPrank(caller);
        _fluid.connectPool(_stakingRewardController.taxDistributionPool());
        _stakingRewardController.updateStakerUnits(stakingAmount);

        assertEq(
            _stakingRewardController.taxDistributionPool().getUnits(caller),
            stakingAmount / _UNIT_DOWNSCALER,
            "incorrect amount of units"
        );

        uint256 expectedYearlySubsidy = stakingAmount * subsidyRate / 10_000;
        int96 expectedSubsidyFlowRate = int256(expectedYearlySubsidy / 365 days).toInt96();

        assertApproxEqAbs(
            _fluid.getFlowRate(address(_stakingRewardController.taxDistributionPool()), caller),
            expectedSubsidyFlowRate,
            uint256(int256(expectedSubsidyFlowRate * 100) / 10_000), // 1% tolerance
            "incorrect subsidy flow rate to staker"
        );

        uint256 balanceBefore = _fluid.balanceOf(caller);

        vm.warp(block.timestamp + 365 days);

        uint256 balanceAfter = _fluid.balanceOf(caller);

        assertApproxEqAbs(
            balanceAfter,
            balanceBefore + expectedYearlySubsidy,
            balanceAfter * 100 / 10_000,
            "incorrect staker balance after"
        );
    }

    function testSetLockerFactory(address newLockerFactory) external {
        vm.assume(newLockerFactory != address(0));
        vm.assume(newLockerFactory != _stakingRewardController.lockerFactory());

        vm.prank(ADMIN);
        _stakingRewardController.setLockerFactory(newLockerFactory);

        assertEq(_stakingRewardController.lockerFactory(), newLockerFactory);

        vm.prank(ADMIN);
        vm.expectRevert(IStakingRewardController.INVALID_PARAMETER.selector);
        _stakingRewardController.setLockerFactory(address(0));
    }

    function testSetSubsidyRate(uint96 _validSubsidyRate, uint96 _invalidSubsidyRate, address nonAdmin) external {
        _validSubsidyRate = uint96(bound(_validSubsidyRate, 0, 10_000));
        vm.assume(_invalidSubsidyRate > 10_000);
        vm.assume(nonAdmin != ADMIN);

        vm.startPrank(ADMIN);
        _stakingRewardController.setSubsidyRate(_validSubsidyRate);

        assertEq(_stakingRewardController.subsidyRate(), _validSubsidyRate, "Subsidy Rate should be updated");

        vm.expectRevert(IStakingRewardController.INVALID_PARAMETER.selector);
        _stakingRewardController.setSubsidyRate(_invalidSubsidyRate);
        vm.stopPrank();

        vm.prank(nonAdmin);
        vm.expectRevert();
        _stakingRewardController.setSubsidyRate(_validSubsidyRate);
    }

    function testWithdraw(uint256 _fundingAmount) external {
        _fundingAmount = bound(_fundingAmount, 1e16, 10_000_000e18);

        vm.prank(FLUID_TREASURY);
        _fluid.transfer(address(_stakingRewardController), _fundingAmount);

        uint256 srcBalanceBeforeOp = _fluid.balanceOf(address(_stakingRewardController));
        uint256 treasuryBalanceBeforeOp = _fluid.balanceOf(FLUID_TREASURY);

        vm.prank(ADMIN);
        _stakingRewardController.withdraw(_fluid, FLUID_TREASURY);

        assertEq(_fluid.balanceOf(address(_stakingRewardController)), 0, "no funds should be left in the contract");
        assertEq(
            _fluid.balanceOf(FLUID_TREASURY),
            srcBalanceBeforeOp + treasuryBalanceBeforeOp,
            "treasury should have received the funds"
        );
    }
}

contract StakingRewardControllerLayoutTest is StakingRewardController {
    constructor() StakingRewardController(ISuperToken(address(0))) { }

    function testStorageLayout() external pure {
        uint256 slot;
        uint256 offset;

        // StakingRewardController storage

        // private state : _approvedLockers
        // slot = 0 - offset = 0

        assembly {
            slot := taxDistributionPool.slot
            offset := taxDistributionPool.offset
        }
        require(slot == 1 && offset == 0, "taxDistributionPool changed location");

        assembly {
            slot := lockerFactory.slot
            offset := lockerFactory.offset
        }
        require(slot == 2 && offset == 0, "lockerFactory changed location");

        assembly {
            slot := subsidyRate.slot
            offset := subsidyRate.offset
        }
        require(slot == 2 && offset == 20, "subsidyRate changed location");
    }
}
