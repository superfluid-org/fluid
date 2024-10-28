// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IPenaltyManager } from "../src/interfaces/IPenaltyManager.sol";

using SuperTokenV1Library for ISuperToken;

contract PenaltyManagerTest is SFTest {
    // Units downscaler defined in PenaltyManager.sol
    uint128 private constant _UNIT_DOWNSCALER = 1e16;

    function setUp() public override {
        super.setUp();
    }

    function testUpdateStakerUnits(address caller, uint256 stakingAmount) external {
        vm.assume(caller != address(0));
        vm.assume(caller != address(_penaltyManager.TAX_DISTRIBUTION_POOL()));
        stakingAmount = bound(stakingAmount, 1e16, 10_000_000e18);

        vm.prank(caller);
        vm.expectRevert(IPenaltyManager.NOT_APPROVED_LOCKER.selector);
        _penaltyManager.updateStakerUnits(stakingAmount);

        vm.prank(address(_fluidLockerFactory));
        _penaltyManager.approveLocker(caller);

        vm.prank(caller);
        _penaltyManager.updateStakerUnits(stakingAmount);

        assertEq(
            _penaltyManager.TAX_DISTRIBUTION_POOL().getUnits(caller),
            stakingAmount / _UNIT_DOWNSCALER,
            "incorrect amount of units"
        );
    }
}
