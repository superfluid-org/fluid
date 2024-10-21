// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { SFTest } from "./SFTest.t.sol";

import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { FluidLocker, IFluidLocker } from "../src/FluidLocker.sol";

using SuperTokenV1Library for ISuperToken;

contract FluidLockerTest is SFTest {
    uint256 public constant PROGRAM_0 = 1;
    uint256 public constant PROGRAM_1 = 2;
    uint256 public constant PROGRAM_2 = 3;
    uint256 public constant signerPkey = 0x69;

    ISuperfluidPool[] public programPools;
    IFluidLocker public aliceLocker;
    IFluidLocker public bobLocker;

    function setUp() public override {
        super.setUp();

        uint256[] memory pIds = new uint256[](3);
        pIds[0] = PROGRAM_0;
        pIds[1] = PROGRAM_1;
        pIds[2] = PROGRAM_2;

        programPools = _helperCreatePrograms(pIds, ADMIN, vm.addr(signerPkey));

        vm.prank(ALICE);
        aliceLocker = IFluidLocker(_fluidLockerFactory.createLockerContract());

        vm.prank(BOB);
        bobLocker = IFluidLocker(_fluidLockerFactory.createLockerContract());
    }

    function testClaim(uint128 units) external {
        units = uint128(bound(units, 1, 1_000_000));

        uint256 nonce = _programManager.getNextValidNonce(PROGRAM_0, address(aliceLocker));
        bytes memory signature = _helperGenerateSignature(signerPkey, address(aliceLocker), units, PROGRAM_0, nonce);

        vm.prank(ALICE);
        aliceLocker.claim(PROGRAM_0, units, nonce, signature);

        assertEq(programPools[0].getUnits(address(aliceLocker)), units, "units not updated");
    }

    function testClaimBatch(uint128 units) external {
        units = uint128(bound(units, 1, 1_000_000));

        uint256[] memory programIds = new uint256[](3);
        uint128[] memory newUnits = new uint128[](3);
        uint256[] memory nonces = new uint256[](3);
        bytes[] memory signatures = new bytes[](3);

        for (uint8 i = 0; i < 3; ++i) {
            programIds[i] = i + 1;
            newUnits[i] = units;
            nonces[i] = _programManager.getNextValidNonce(programIds[i], address(aliceLocker));
            signatures[i] = _helperGenerateSignature(signerPkey, address(aliceLocker), units, programIds[i], nonces[i]);
        }

        vm.prank(ALICE);
        aliceLocker.claim(programIds, newUnits, nonces, signatures);

        for (uint8 i = 0; i < 3; ++i) {
            assertEq(newUnits[i], programPools[i].getUnits(address(aliceLocker)), "incorrect units amounts");
        }
    }

    function testLock(uint256 amount) external {
        amount = bound(amount, 1e18, 1e24);
        assertEq(_fluidSuperToken.balanceOf(address(aliceLocker)), 0, "incorrect balance before operation");

        vm.startPrank(FLUID_TREASURY);
        _fluidSuperToken.approve(address(aliceLocker), amount);
        aliceLocker.lock(amount);
        vm.stopPrank();

        assertEq(_fluidSuperToken.balanceOf(address(aliceLocker)), amount, "incorrect balance after operation");
    }

    function testInstantUnlock() external {
        _helperFundLocker(address(aliceLocker), 10_000e18);
        _helperBobStaking();

        assertEq(_fluidSuperToken.balanceOf(address(ALICE)), 0, "incorrect Alice bal before op");
        assertEq(_fluidSuperToken.balanceOf(address(aliceLocker)), 10_000e18, "incorrect Locker bal before op");
        assertEq(bobLocker.getAvailableBalance(), 0, "incorrect Bob bal before op");

        vm.prank(ALICE);
        aliceLocker.unlock(0);

        assertEq(_fluidSuperToken.balanceOf(address(ALICE)), 2_000e18, "incorrect Alice bal after op");
        assertEq(_fluidSuperToken.balanceOf(address(aliceLocker)), 0, "incorrect bal after op");
        assertEq(bobLocker.getAvailableBalance(), 8_000e18, "incorrect Bob bal after op");

        vm.prank(ALICE);
        vm.expectRevert(IFluidLocker.NO_FLUID_TO_UNLOCK.selector);
        aliceLocker.unlock(0);
    }

    function testVestUnlock() external { }
    function testCancelUnlock() external { }

    function testStake() external {
        uint256 funding = 10_000e18;
        _helperFundLocker(address(aliceLocker), funding);
        assertEq(_fluidSuperToken.balanceOf(address(aliceLocker)), funding, "incorrect Locker bal before op");
        assertEq(aliceLocker.getAvailableBalance(), funding, "incorrect available bal before op");
        assertEq(aliceLocker.getStakedBalance(), 0, "incorrect staked bal before op");

        vm.prank(ALICE);
        aliceLocker.stake();

        assertEq(aliceLocker.getAvailableBalance(), 0, "incorrect available bal after op");
        assertEq(aliceLocker.getStakedBalance(), funding, "incorrect staked bal after op");
        assertEq(
            _penaltyManager.TAX_DISTRIBUTION_POOL().getUnits(address(aliceLocker)), funding / 1e6, "incorrect units"
        );

        vm.prank(ALICE);
        vm.expectRevert(IFluidLocker.NO_FLUID_TO_STAKE.selector);
        aliceLocker.stake();
    }

    function testUnstake() external {
        uint256 funding = 10_000e18;
        _helperFundLocker(address(aliceLocker), funding);
        vm.startPrank(ALICE);
        aliceLocker.stake();

        assertEq(aliceLocker.getAvailableBalance(), 0, "incorrect available bal before op");
        assertEq(aliceLocker.getStakedBalance(), funding, "incorrect staked bal before op");
        assertEq(
            _penaltyManager.TAX_DISTRIBUTION_POOL().getUnits(address(aliceLocker)),
            funding / 1e6,
            "incorrect units before op"
        );

        vm.expectRevert(IFluidLocker.STAKING_COOLDOWN_NOT_ELAPSED.selector);
        aliceLocker.unstake();

        vm.warp(uint256(FluidLocker(address(aliceLocker)).stakingUnlocksAt()) + 1);
        aliceLocker.unstake();

        assertEq(aliceLocker.getAvailableBalance(), funding, "incorrect available bal after op");
        assertEq(aliceLocker.getStakedBalance(), 0, "incorrect staked bal after op");
        assertEq(_penaltyManager.TAX_DISTRIBUTION_POOL().getUnits(address(aliceLocker)), 0, "incorrect units after op");

        vm.expectRevert(IFluidLocker.NO_FLUID_TO_UNSTAKE.selector);
        aliceLocker.unstake();

        vm.stopPrank();
    }

    function testTransferLocker() external { }

    function testGetFontaineBeaconImplementation() external view {
        assertEq(_fluidLockerLogic.getFontaineBeaconImplementation(), address(_fontaineLogic));
    }

    function _helperFundLocker(address locker, uint256 amount) internal {
        vm.prank(FLUID_TREASURY);
        _fluidSuperToken.transfer(locker, amount);
    }

    function _helperBobStaking() internal {
        _helperFundLocker(address(bobLocker), 10_000e18);
        vm.prank(BOB);
        bobLocker.stake();
    }
}
