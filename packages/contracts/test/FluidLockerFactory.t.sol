// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IFluidLockerFactory } from "../src/interfaces/IFluidLockerFactory.sol";

using SuperTokenV1Library for ISuperToken;

contract FluidLockerFactoryTest is SFTest {
    function setUp() public override {
        super.setUp();
    }

    function testCreateLockerContract() external { }
    function testIsLockerCreated() external { }
    function testGetLockerAddress() external { }

    function testGetLockerBeaconImplementation() external view {
        assertEq(_fluidLockerFactory.getLockerBeaconImplementation(), address(_fluidLockerLogic));
    }

    function testGetFontaineBeaconImplementation() external view {
        assertEq(_fluidLockerFactory.getFontaineBeaconImplementation(), address(_fontaineLogic));
    }
}
