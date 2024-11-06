// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { EPProgramManager, IEPProgramManager } from "../src/EPProgramManager.sol";
import { IFluidLocker } from "../src/interfaces/IFluidLocker.sol";

using SuperTokenV1Library for ISuperToken;
using ECDSA for bytes32;

/// @dev Unit tests for Base EPProgramManager (EPProgramManager.sol)
contract EPProgramManagerTest is SFTest {
    function setUp() public override {
        super.setUp();

        _programManager = new EPProgramManager();
    }

    function testCreateProgram(uint256 _pId, address _admin, address _signer) external {
        vm.assume(_pId != 0);
        vm.assume(_admin != address(0));
        vm.assume(_signer != address(0));

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

    function testCreateProgramReverts(uint256 _pId, address _admin, address _signer) external {
        vm.assume(_pId != 0);
        vm.assume(_admin != address(0));
        vm.assume(_signer != address(0));

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(0, _admin, _signer, _fluidSuperToken);

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(_pId, address(0), _signer, _fluidSuperToken);

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(_pId, _admin, address(0), _fluidSuperToken);

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(_pId, _admin, _signer, ISuperToken(address(0)));
    }

    function testUpdateProgramSigner(
        uint256 _pId,
        address _admin,
        address _nonAdmin,
        address _signer,
        address _newSigner
    ) external {
        vm.assume(_pId > 1);
        vm.assume(_admin != address(0));
        vm.assume(_signer != address(0));
        vm.assume(_newSigner != address(0));
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

        vm.prank(_admin);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.updateProgramSigner(_pId, address(0));

        vm.prank(_admin);
        vm.expectRevert(IEPProgramManager.PROGRAM_NOT_FOUND.selector);
        _programManager.updateProgramSigner(1, _newSigner);
    }

    function testUpdateUnits(uint96 _signerPkey, uint96 _invalidSignerPkey, address _user, uint256 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_invalidSignerPkey != 0);
        vm.assume(_signerPkey != _invalidSignerPkey);
        vm.assume(_user != address(0));
        vm.assume(_user != address(_stakingRewardController.TAX_DISTRIBUTION_POOL()));
        _units = bound(_units, 1, 1_000_000);

        uint256 programId = 1;

        ISuperfluidPool pool = _helperCreateProgram(programId, ADMIN, vm.addr(_signerPkey));

        uint256 nonce = _programManager.getNextValidNonce(programId, _user);
        bytes memory validSignature = _helperGenerateSignature(_signerPkey, _user, _units, programId, nonce);

        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        assertEq(pool.getUnits(_user), _units, "units not updated");

        // Test updateUnits with an invalid nonce
        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "nonce"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        // Test updateUnits with an invalid signer
        nonce = _programManager.getNextValidNonce(programId, _user);
        bytes memory invalidSignature = _helperGenerateSignature(_invalidSignerPkey, _user, _units, programId, nonce);

        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "signer"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, invalidSignature);

        // Test updateUnits with an invalid signature length
        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "signature length"));
        vm.prank(_user);
        _programManager.updateUnits(programId, _units, nonce, "0x");

        // Test updateUnits with an invalid user address
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        vm.prank(address(0));
        _programManager.updateUnits(programId, _units, nonce, validSignature);
    }

    function testBatchUpdateUnits(uint8 _batchAmount, uint96 _signerPkey, address _user, uint256 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_user != address(0));
        vm.assume(_user != address(_stakingRewardController.TAX_DISTRIBUTION_POOL()));
        _units = bound(_units, 1, 1_000_000);
        _batchAmount = uint8(bound(_batchAmount, 2, 8));

        uint256[] memory programIds = new uint256[](_batchAmount);
        uint256[] memory newUnits = new uint256[](_batchAmount);
        uint256[] memory nonces = new uint256[](_batchAmount);
        bytes[] memory stackSignatures = new bytes[](_batchAmount);
        ISuperfluidPool[] memory pools = new ISuperfluidPool[](_batchAmount);

        for (uint8 i = 0; i < _batchAmount; ++i) {
            programIds[i] = i + 1;
            pools[i] = _helperCreateProgram(programIds[i], ADMIN, vm.addr(_signerPkey));

            newUnits[i] = _units;
            nonces[i] = _programManager.getNextValidNonce(programIds[i], _user);
            stackSignatures[i] = _helperGenerateSignature(_signerPkey, _user, newUnits[i], programIds[i], nonces[i]);
        }

        vm.prank(_user);
        _programManager.batchUpdateUnits(programIds, newUnits, nonces, stackSignatures);

        for (uint8 i = 0; i < _batchAmount; ++i) {
            assertEq(newUnits[i], pools[i].getUnits(_user), "incorrect units amounts");
        }
    }

    function testBatchUpdateUnitsInvalidArrayLength(uint96 _signerPkey, address _user, uint256 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_user != address(0));
        _units = bound(_units, 1, 1_000_000);

        uint256[] memory programIds = new uint256[](2);
        uint256[] memory newUnits = new uint256[](2);
        uint256[] memory nonces = new uint256[](2);
        bytes[] memory stackSignatures = new bytes[](2);
        ISuperfluidPool[] memory pools = new ISuperfluidPool[](2);

        for (uint8 i = 0; i < 2; ++i) {
            programIds[i] = i + 1;
            pools[i] = _helperCreateProgram(programIds[i], ADMIN, vm.addr(_signerPkey));

            newUnits[i] = _units;
            nonces[i] = _programManager.getNextValidNonce(programIds[i], _user);
            stackSignatures[i] = _helperGenerateSignature(_signerPkey, _user, newUnits[i], programIds[i], nonces[i]);
        }

        uint256[] memory invalidProgramIds = new uint256[](0);

        vm.prank(_user);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.batchUpdateUnits(invalidProgramIds, newUnits, nonces, stackSignatures);

        uint256[] memory invalidNewUnits = new uint256[](1);
        invalidNewUnits[0] = newUnits[0];

        vm.prank(_user);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.batchUpdateUnits(programIds, invalidNewUnits, nonces, stackSignatures);

        uint256[] memory invalidNonces = new uint256[](1);
        invalidNonces[0] = nonces[0];

        bytes[] memory invalidStackSignatures = new bytes[](1);
        invalidStackSignatures[0] = stackSignatures[0];

        vm.prank(_user);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.batchUpdateUnits(programIds, newUnits, nonces, invalidStackSignatures);
    }
}

contract FluidEPProgramManagerTest is SFTest {
    IFluidLocker public aliceLocker;

    function setUp() public override {
        super.setUp();

        vm.prank(ALICE);
        aliceLocker = IFluidLocker(_fluidLockerFactory.createLockerContract());
    }

    function testCreateProgram(uint256 _pId, address _admin, address _signer) external {
        vm.assume(_pId != 0);
        vm.assume(_admin != address(0));
        vm.assume(_signer != address(0));

        vm.prank(ADMIN);
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

        vm.prank(ADMIN);
        vm.expectRevert(IEPProgramManager.PROGRAM_ALREADY_CREATED.selector);
        _programManager.createProgram(_pId, _admin, _signer, _fluidSuperToken);
    }

    function testCreateProgramReverts(uint256 _pId, address _admin, address _signer) external {
        vm.assume(_pId != 0);
        vm.assume(_admin != address(0));
        vm.assume(_signer != address(0));

        vm.startPrank(ADMIN);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(0, _admin, _signer, _fluidSuperToken);

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(_pId, address(0), _signer, _fluidSuperToken);

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(_pId, _admin, address(0), _fluidSuperToken);

        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.createProgram(_pId, _admin, _signer, ISuperToken(address(0)));

        vm.stopPrank();
    }

    function testUpdateProgramSigner(
        uint256 _pId,
        address _admin,
        address _nonAdmin,
        address _signer,
        address _newSigner
    ) external {
        vm.assume(_pId > 1);
        vm.assume(_admin != address(0));
        vm.assume(_signer != address(0));
        vm.assume(_newSigner != address(0));
        vm.assume(_signer != _newSigner);
        vm.assume(_admin != _nonAdmin);

        vm.prank(ADMIN);
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

        vm.prank(_admin);
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        _programManager.updateProgramSigner(_pId, address(0));

        vm.prank(_admin);
        vm.expectRevert(IEPProgramManager.PROGRAM_NOT_FOUND.selector);
        _programManager.updateProgramSigner(1, _newSigner);
    }

    function testUpdateUnits(uint96 _signerPkey, uint96 _invalidSignerPkey, uint256 _units) external {
        vm.assume(_signerPkey != 0);
        vm.assume(_invalidSignerPkey != 0);
        vm.assume(_signerPkey != _invalidSignerPkey);
        _units = bound(_units, 1, 1_000_000);

        uint256 programId = 1;

        ISuperfluidPool pool = _helperCreateProgram(programId, ADMIN, vm.addr(_signerPkey));

        uint256 nonce = _programManager.getNextValidNonce(programId, ALICE);
        bytes memory validSignature = _helperGenerateSignature(_signerPkey, ALICE, _units, programId, nonce);

        vm.prank(ALICE);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        assertEq(pool.getUnits(address(aliceLocker)), _units, "units not updated");

        // Test updateUnits with an invalid nonce
        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "nonce"));
        vm.prank(ALICE);
        _programManager.updateUnits(programId, _units, nonce, validSignature);

        // Test updateUnits with an invalid signer
        nonce = _programManager.getNextValidNonce(programId, ALICE);
        bytes memory invalidSignature = _helperGenerateSignature(_invalidSignerPkey, ALICE, _units, programId, nonce);

        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "signer"));
        vm.prank(ALICE);
        _programManager.updateUnits(programId, _units, nonce, invalidSignature);

        // Test updateUnits with an invalid signature length
        vm.expectRevert(abi.encodeWithSelector(IEPProgramManager.INVALID_SIGNATURE.selector, "signature length"));
        vm.prank(ALICE);
        _programManager.updateUnits(programId, _units, nonce, "0x");

        // Test updateUnits with an invalid user address
        vm.expectRevert(IEPProgramManager.INVALID_PARAMETER.selector);
        vm.prank(address(0));
        _programManager.updateUnits(programId, _units, nonce, validSignature);
    }

    function testBatchUpdateUnits(uint8 _batchAmount, uint96 _signerPkey, uint256 _units) external {
        vm.assume(_signerPkey != 0);
        _units = bound(_units, 1, 1_000_000);
        _batchAmount = uint8(bound(_batchAmount, 2, 8));

        uint256[] memory programIds = new uint256[](_batchAmount);
        uint256[] memory newUnits = new uint256[](_batchAmount);
        uint256[] memory nonces = new uint256[](_batchAmount);
        bytes[] memory stackSignatures = new bytes[](_batchAmount);
        ISuperfluidPool[] memory pools = new ISuperfluidPool[](_batchAmount);

        for (uint8 i = 0; i < _batchAmount; ++i) {
            programIds[i] = i + 1;
            pools[i] = _helperCreateProgram(programIds[i], ADMIN, vm.addr(_signerPkey));

            newUnits[i] = _units;
            nonces[i] = _programManager.getNextValidNonce(programIds[i], ALICE);
            stackSignatures[i] = _helperGenerateSignature(_signerPkey, ALICE, newUnits[i], programIds[i], nonces[i]);
        }

        vm.prank(ALICE);
        _programManager.batchUpdateUnits(programIds, newUnits, nonces, stackSignatures);

        for (uint8 i = 0; i < _batchAmount; ++i) {
            assertEq(newUnits[i], pools[i].getUnits(address(aliceLocker)), "incorrect units amounts");
        }
    }
}
