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

    function testCreateLockerContract(address _user) external {
        vm.assume(_user != address(0));

        address predictedAddress = _fluidLockerFactory.getLockerAddress(_user);
        assertEq(_fluidLockerFactory.isLockerCreated(predictedAddress), false, "locker should not exists");

        vm.prank(_user);
        address userLockerAddress = _fluidLockerFactory.createLockerContract();

        assertEq(_fluidLockerFactory.isLockerCreated(userLockerAddress), true, "locker should exists");
        assertEq(predictedAddress, userLockerAddress, "predicted address should match");
    }

    function testGetLockerBeaconImplementation() external view {
        assertEq(_fluidLockerFactory.getLockerBeaconImplementation(), address(_fluidLockerLogic));
    }

    function testGetFontaineBeaconImplementation() external view {
        assertEq(_fluidLockerFactory.getFontaineBeaconImplementation(), address(_fontaineLogic));
    }
}
