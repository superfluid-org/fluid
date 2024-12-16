// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";
import { TreasuryGadget } from "../src/TreasuryGadget.sol";
import { ITreasuryGadget } from "../src/interfaces/ITreasuryGadget.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";
import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

using SafeCast for int256;
using SuperTokenV1Library for ISuperToken;

contract TreasuryGadgetTest is SFTest {
    TreasuryGadget public treasuryGadget;

    address public communityMultisig;

    uint256 public constant FUNDING_AMOUNT = 350_000_000 ether;
    uint256 public constant CLIFF_AMOUNT = 50_000_000 ether;
    uint256 public constant FUNDING_DURATION = 730 days; // 2 years
    int96 public fundingFlowRate;

    function setUp() public virtual override {
        super.setUp();

        fundingFlowRate = int256((FUNDING_AMOUNT - CLIFF_AMOUNT) / FUNDING_DURATION).toInt96();

        // Setup addresses
        communityMultisig = makeAddr("communityMultisig");

        // Deploy TreasuryGadget
        treasuryGadget = new TreasuryGadget(_fluid, communityMultisig, FLUID_TREASURY);
    }

    function testConstructor() public view {
        assertEq(address(treasuryGadget.FLUID()), address(_fluid));
        assertEq(treasuryGadget.COMMUNITY_MULTISIG(), communityMultisig);
        assertEq(treasuryGadget.owner(), FLUID_TREASURY);
    }

    function testFundCommunityMultisig() public {
        uint256 buffer = uint96(fundingFlowRate * 4 hours);

        vm.startPrank(FLUID_TREASURY);
        _fluid.approve(address(treasuryGadget), FUNDING_AMOUNT);

        treasuryGadget.fundCommunityMultisig(FUNDING_AMOUNT, CLIFF_AMOUNT, fundingFlowRate);
        vm.stopPrank();

        // Verify balances
        assertEq(_fluid.balanceOf(communityMultisig), CLIFF_AMOUNT, "Community multisig balance mismatch");

        assertApproxEqAbs(
            _fluid.balanceOf(address(treasuryGadget)),
            FUNDING_AMOUNT - CLIFF_AMOUNT - buffer,
            _fluid.balanceOf(address(treasuryGadget)) / 1000, // 0.1% percent precision error tolerance
            "TreasuryGadget balance mismatch"
        );
    }

    function testFundCommunityMultisigRevertCliffGreaterThanTotal() public {
        uint256 totalAmount = 35_000_000 ether;
        uint256 cliffAmount = 350_000_000 ether;
        int96 flowRate = 1 ether;

        vm.startPrank(FLUID_TREASURY);
        _fluid.approve(address(treasuryGadget), totalAmount);

        vm.expectRevert(ITreasuryGadget.INVALID_PARAMETER.selector);
        treasuryGadget.fundCommunityMultisig(totalAmount, cliffAmount, flowRate);
        vm.stopPrank();
    }

    function testUpdateFunding(int96 newFlowRate) public {
        newFlowRate = int96(bound(newFlowRate, 0, fundingFlowRate - 1));
        _helperFundCommunityMultisig();

        vm.prank(FLUID_TREASURY);
        treasuryGadget.updateFunding(newFlowRate);

        // Verify flow rate update
        assertEq(
            _fluid.getCFAFlowRate(address(treasuryGadget), communityMultisig), newFlowRate, "Updated flow rate mismatch"
        );
    }

    function testWithdraw(uint256 amount) public {
        _helperFundCommunityMultisig();

        uint256 treasuryBalanceBefore = _fluid.balanceOf(FLUID_TREASURY);
        uint256 gadgetBalanceBefore = _fluid.balanceOf(address(treasuryGadget));

        amount = bound(amount, 1, gadgetBalanceBefore);

        vm.prank(FLUID_TREASURY);
        treasuryGadget.withdraw(amount);

        assertEq(_fluid.balanceOf(FLUID_TREASURY), treasuryBalanceBefore + amount, "Treasury balance mismatch");
        assertEq(
            _fluid.balanceOf(address(treasuryGadget)), gadgetBalanceBefore - amount, "TreasuryGadget balance mismatch"
        );
    }

    function testWithdrawAll() public {
        uint256 treasuryBalanceBefore = _fluid.balanceOf(FLUID_TREASURY);
        uint256 gadgetBalanceBefore = _fluid.balanceOf(address(treasuryGadget));

        vm.prank(FLUID_TREASURY);
        treasuryGadget.withdrawAll();

        assertEq(
            _fluid.balanceOf(FLUID_TREASURY), treasuryBalanceBefore + gadgetBalanceBefore, "Treasury balance mismatch"
        );
        assertEq(_fluid.balanceOf(address(treasuryGadget)), 0, "TreasuryGadget balance mismatch");
    }

    function testRevertWhenNonOwnerCalls(address nonOwner) public {
        vm.assume(nonOwner != FLUID_TREASURY);

        vm.startPrank(nonOwner);

        vm.expectRevert();
        treasuryGadget.fundCommunityMultisig(100 ether, 20 ether, 1 ether);

        vm.expectRevert();
        treasuryGadget.updateFunding(2 ether);

        vm.expectRevert();
        treasuryGadget.withdraw(50 ether);

        vm.expectRevert();
        treasuryGadget.withdrawAll();

        vm.stopPrank();
    }

    function _helperFundCommunityMultisig() internal {
        vm.startPrank(FLUID_TREASURY);
        _fluid.approve(address(treasuryGadget), FUNDING_AMOUNT);

        treasuryGadget.fundCommunityMultisig(FUNDING_AMOUNT, CLIFF_AMOUNT, fundingFlowRate);
        vm.stopPrank();
    }
}
