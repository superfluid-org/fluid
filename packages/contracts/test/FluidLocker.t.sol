// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IFluidLocker } from "../src/interfaces/IFluidLocker.sol";

using SuperTokenV1Library for ISuperToken;

contract FluidLockerTest is SFTest {
    function setUp() public override {
        super.setUp();
    }

    function testClaim() external { }
    function testBatchClaim() external { }
    function testLock() external { }
    function testInstantUnlock() external { }
    function testVestUnlock() external { }
    function testCancelUnlock() external { }
    function testStake() external { }
    function testUnstake() external { }
    function testTransferLocker() external { }

    function testGetFontaineBeaconImplementation() external view {
        assertEq(_fluidLockerFactory.getFontaineBeaconImplementation(), address(_fontaineLogic));
    }
}
