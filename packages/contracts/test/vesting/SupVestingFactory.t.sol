// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { console2 } from "forge-std/Test.sol";
import { SFTest } from "../SFTest.t.sol";
import { ISupVestingFactory, SupVestingFactory } from "src/vesting/SupVestingFactory.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import { VestingSchedulerV2 } from "@superfluid-finance/automation-contracts/scheduler/contracts/VestingSchedulerV2.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";

contract SupVestingFactoryTest is SFTest {
    SupVestingFactory public supVestingFactory;
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
    }

    function testCreateSupVestingContractPrefunded(
        address nonAdmin,
        address recipient,
        uint256 amount,
        bool isPrefunded
    ) public {
        vm.assume(nonAdmin != address(ADMIN));
        vm.assume(recipient != address(0));
        amount = bound(amount, 1_000 ether, 1_000_000 ether);

        uint32 startDate = uint32(block.timestamp + 1 days);

        if (isPrefunded) {
            vm.prank(FLUID_TREASURY);
            _fluidSuperToken.approve(address(supVestingFactory), amount);
        }

        vm.prank(nonAdmin);
        vm.expectRevert(ISupVestingFactory.FORBIDDEN.selector);
        supVestingFactory.createSupVestingContract(
            recipient, amount, VESTING_DURATION, startDate, CLIFF_PERIOD, isPrefunded
        );

        uint256 supplyBefore = supVestingFactory.totalSupply();

        vm.prank(ADMIN);
        supVestingFactory.createSupVestingContract(
            recipient, amount, VESTING_DURATION, startDate, CLIFF_PERIOD, isPrefunded
        );

        address newSupVestingContract = supVestingFactory.supVestings(recipient);

        if (!isPrefunded) {
            vm.prank(FLUID_TREASURY);
            _fluidSuperToken.transfer(newSupVestingContract, amount);
        }

        assertNotEq(newSupVestingContract, address(0), "New sup vesting contract should be created");
        assertEq(supVestingFactory.balanceOf(recipient), amount, "Balance should be updated");
        assertEq(supVestingFactory.totalSupply(), supplyBefore + amount, "Total supply should be updated");

        vm.prank(ADMIN);
        vm.expectRevert(ISupVestingFactory.RECIPIENT_ALREADY_HAS_VESTING_CONTRACT.selector);
        supVestingFactory.createSupVestingContract(recipient, amount, VESTING_DURATION, startDate, CLIFF_PERIOD, true);
    }

    function testSetTreasury(address newTreasury, address nonAdmin) public {
        vm.assume(nonAdmin != address(ADMIN));
        vm.assume(newTreasury != address(0));
        vm.assume(newTreasury != address(FLUID_TREASURY));

        vm.prank(nonAdmin);
        vm.expectRevert(ISupVestingFactory.FORBIDDEN.selector);
        supVestingFactory.setTreasury(newTreasury);

        vm.startPrank(ADMIN);
        vm.expectRevert(ISupVestingFactory.FORBIDDEN.selector);
        supVestingFactory.setTreasury(address(0));

        supVestingFactory.setTreasury(newTreasury);
        vm.stopPrank();

        assertEq(supVestingFactory.treasury(), newTreasury, "Treasury should be updated to the new treasury");
    }

    function testSetAdmin(address newAdmin, address nonAdmin) public {
        vm.assume(nonAdmin != address(ADMIN));
        vm.assume(newAdmin != address(0));
        vm.assume(newAdmin != address(ADMIN));

        vm.prank(nonAdmin);
        vm.expectRevert(ISupVestingFactory.FORBIDDEN.selector);
        supVestingFactory.setAdmin(newAdmin);

        vm.startPrank(ADMIN);
        vm.expectRevert(ISupVestingFactory.FORBIDDEN.selector);
        supVestingFactory.setAdmin(address(0));

        supVestingFactory.setAdmin(newAdmin);
        vm.stopPrank();

        assertEq(supVestingFactory.admin(), newAdmin, "Admin should be updated to the new admin");
    }
}
