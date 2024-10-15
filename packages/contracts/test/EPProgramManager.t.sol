// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console } from "forge-std/console.sol";

import { SFTest } from "./SFTest.t.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IEPProgramManager } from "../src/interfaces/IEPProgramManager.sol";

using SuperTokenV1Library for ISuperToken;
using ECDSA for bytes32;

contract EPProgramManagerTest is SFTest {
    function setUp() public override {
        super.setUp();
    }

    function testCreateProgram(uint96 _pId, address _admin, address _signer) external {
        ISuperfluidPool pool = _programManager.createProgram(_pId, _admin, _signer, _fluidSuperToken);

        (address programAdmin, address stackSigner, ISuperToken token, ISuperfluidPool distributionPool) =
            _programManager.programs(_pId);

        assertEq(programAdmin, _admin, "incorrect admin");
        assertEq(stackSigner, _signer, "incorrect signer");
        assertEq(address(token), address(_fluidSuperToken), "incorrect token");
        assertEq(address(distributionPool), address(pool), "incorrect pool");

        vm.expectRevert(IEPProgramManager.PROGRAM_ALREADY_CREATED.selector);
        _programManager.createProgram(_pId, _admin, _signer, _fluidSuperToken);
    }

    function testUpdateSigner(uint96 _pId, address _admin, address _nonAdmin, address _signer, address _newSigner)
        external
    {
        vm.assume(_signer != _newSigner);
        vm.assume(_admin != _nonAdmin);

        _programManager.createProgram(_pId, _admin, _signer, _fluidSuperToken);
        (, address signerBefore,,) = _programManager.programs(_pId);

        assertEq(signerBefore, _signer, "incorrect signer before update");

        vm.prank(_admin);
        _programManager.updateProgramSigner(_pId, _newSigner);

        (, address signerAfter,,) = _programManager.programs(_pId);
        assertEq(signerAfter, _newSigner, "incorrect signer after update");

        vm.prank(_nonAdmin);
        vm.expectRevert(IEPProgramManager.NOT_PROGRAM_ADMIN.selector);
        _programManager.updateProgramSigner(_pId, _signer);
    }

    function testUpdateUnits(uint96 _signerPkey, uint96 _invalidSignerPkey, address _user, uint128 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_invalidSignerPkey != 0);
        vm.assume(_signerPkey != _invalidSignerPkey);
        vm.assume(_user != address(0));
        _units = uint128(bound(_units, 1, 1_000_000));

        uint96 programId = 0;

        ISuperfluidPool pool = _helperCreateProgram(programId, ADMIN, vm.addr(_signerPkey));

        uint256 nonce = 1;
        bytes32 digest = keccak256(abi.encodePacked(_user, _units, programId, nonce)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPkey, digest);
        bytes memory validSignature = abi.encodePacked(r, s, v);

        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        assertEq(pool.getUnits(_user), _units, "units not updated");

        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "nonce"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, validSignature);
    }

    function testUpdateUnitsBatch() external { }
    function testUpdateUnitsInvalidNonce() external { }
    function testUpdateUnitsInvalidSigner() external { }
    function testUpdateUnitsInvalidSignatureLength() external { }

    function testLogErrors() external pure {
        console.logBytes4(IEPProgramManager.NOT_PROGRAM_ADMIN.selector);
    }
}
