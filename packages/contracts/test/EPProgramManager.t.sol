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
        assertEq(
            address(_programManager.getProgramPool(_pId)), address(pool), "getProgramPool returns an incorrect pool"
        );

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

        uint256 nonce = _programManager.getNextValidNonce(programId, _user);
        bytes32 digest = keccak256(abi.encodePacked(_user, _units, programId, nonce)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPkey, digest);
        bytes memory validSignature = abi.encodePacked(r, s, v);

        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        assertEq(pool.getUnits(_user), _units, "units not updated");

        // Test updateUnits with an invalid nonce
        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "nonce"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        // Test updateUnits with an invalid signer
        nonce = _programManager.getNextValidNonce(programId, _user);
        (v, r, s) = vm.sign(_invalidSignerPkey, digest);
        bytes memory invalidSignature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "signer"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, invalidSignature);

        // Test updateUnits with an invalid signature length
        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "signature length"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, "0x");
    }

    function testUpdateUnitsBatch(uint8 _batchAmount, uint96 _signerPkey, address _user, uint128 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_user != address(0));
        _units = uint128(bound(_units, 1, 1_000_000));
        _batchAmount = uint8(bound(_batchAmount, 2, 8));

        uint96[] memory programIds = new uint96[](_batchAmount);
        uint128[] memory newUnits = new uint128[](_batchAmount);
        uint256[] memory nonces = new uint256[](_batchAmount);
        bytes[] memory stackSignatures = new bytes[](_batchAmount);
        ISuperfluidPool[] memory pools = new ISuperfluidPool[](_batchAmount);

        for (uint8 i = 0; i < _batchAmount; ++i) {
            programIds[i] = i;
            pools[i] = _helperCreateProgram(programIds[i], ADMIN, vm.addr(_signerPkey));

            newUnits[i] = _units;
            nonces[i] = _programManager.getNextValidNonce(programIds[i], _user);
            bytes32 digest =
                keccak256(abi.encodePacked(_user, newUnits[i], programIds[i], nonces[i])).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPkey, digest);
            stackSignatures[i] = abi.encodePacked(r, s, v);
        }

        vm.prank(_user);
        _programManager.updateUnits(programIds, newUnits, nonces, stackSignatures);

        for (uint8 i = 0; i < _batchAmount; ++i) {
            assertEq(newUnits[i], pools[i].getUnits(_user), "incorrect units amounts");
        }
    }

    function testUpdateUnitsBatchInvalidArrayLength(uint96 _signerPkey, address _user, uint128 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_user != address(0));
        _units = uint128(bound(_units, 1, 1_000_000));

        uint96[] memory programIds = new uint96[](2);
        uint128[] memory newUnits = new uint128[](2);
        uint256[] memory nonces = new uint256[](2);
        bytes[] memory stackSignatures = new bytes[](2);
        ISuperfluidPool[] memory pools = new ISuperfluidPool[](2);

        for (uint8 i = 0; i < 2; ++i) {
            programIds[i] = i;
            pools[i] = _helperCreateProgram(programIds[i], ADMIN, vm.addr(_signerPkey));

            newUnits[i] = _units;
            nonces[i] = _programManager.getNextValidNonce(programIds[i], _user);
            bytes32 digest =
                keccak256(abi.encodePacked(_user, newUnits[i], programIds[i], nonces[i])).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(_signerPkey, digest);
            stackSignatures[i] = abi.encodePacked(r, s, v);
        }

        uint96[] memory invalidProgramIds = new uint96[](1);
        invalidProgramIds[0] = programIds[0];

        vm.prank(_user);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.updateUnits(invalidProgramIds, newUnits, nonces, stackSignatures);

        uint128[] memory invalidNewUnits = new uint128[](1);
        invalidNewUnits[0] = newUnits[0];

        vm.prank(_user);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.updateUnits(programIds, invalidNewUnits, nonces, stackSignatures);

        uint256[] memory invalidNonces = new uint256[](1);
        invalidNonces[0] = nonces[0];

        bytes[] memory invalidStackSignatures = new bytes[](1);
        invalidStackSignatures[0] = stackSignatures[0];

        vm.prank(_user);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.updateUnits(programIds, newUnits, nonces, invalidStackSignatures);
    }
}
