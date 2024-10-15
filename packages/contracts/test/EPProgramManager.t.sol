// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/Test.sol";

import { SFTest } from "./SFTest.t.sol";
import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

using SuperTokenV1Library for ISuperToken;

contract EPProgramManagerTest is SFTest {
    function setUp() public override {
        super.setUp();
    }

    function testCreateProgram() external { }
    function testCreateProgramAlreadyExists() external { }

    function testUpdateSigner() external { }
    function testUpdateSignerNotProgramAdmin() external { }

    function testUpdateUnits() external { }
    function testUpdateUnitsBatch() external { }
    function testUpdateUnitsInvalidNonce() external { }
    function testUpdateUnitsInvalidSigner() external { }
    function testUpdateUnitsInvalidSignatureLength() external { }
}
