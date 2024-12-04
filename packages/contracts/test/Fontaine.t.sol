// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/Test.sol";

import { SFTest } from "./SFTest.t.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { Math } from "@openzeppelin-v5/contracts/utils/math/Math.sol";
import {
    ISuperToken,
    ISuperfluidPool
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IFluidLocker } from "../src/FluidLocker.sol";
import { IFontaine } from "../src/interfaces/IFontaine.sol";
import { Fontaine } from "../src/Fontaine.sol";
import { calculateVestUnlockFlowRates } from "../src/FluidLocker.sol";

using SuperTokenV1Library for ISuperToken;
using SafeCast for int256;

contract FontaineTest is SFTest {
    uint128 internal constant _MIN_UNLOCK_PERIOD = 7 days;
    uint128 internal constant _MAX_UNLOCK_PERIOD = 540 days;
    uint256 internal constant _BP_DENOMINATOR = 10_000;
    uint256 internal constant _SCALER = 1e18;

    IFluidLocker public bobLocker;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(BOB);
        bobLocker = IFluidLocker(_fluidLockerFactory.createLockerContract());
    }

    function testInitialize(uint128 unlockPeriod, uint256 unlockAmount) external {
        unlockPeriod = uint128(bound(unlockPeriod, _MIN_UNLOCK_PERIOD, _MAX_UNLOCK_PERIOD));
        unlockAmount = bound(unlockAmount, 1_000e18, 100_000e18);

        _helperBobStaking();
        (int96 taxFlowRate, int96 unlockFlowRate) = _helperCalculateUnlockFlowRates(unlockAmount, unlockPeriod);

        address newFontaine = _helperCreateFontaine();

        address user = makeAddr("user");
        vm.prank(FLUID_TREASURY);
        _fluid.transfer(newFontaine, unlockAmount);

        IFontaine(newFontaine).initialize(user, unlockFlowRate, taxFlowRate, unlockPeriod);

        assertEq(Fontaine(newFontaine).endDate(), uint128(block.timestamp) + unlockPeriod, "end date incorreclty set");
        assertEq(Fontaine(newFontaine).taxFlowRate(), uint96(taxFlowRate), "tax flow rate incorreclty set");
        assertEq(Fontaine(newFontaine).unlockFlowRate(), uint96(unlockFlowRate), "unlock flow rate incorreclty set");

        (, int96 actualTaxFlowRate) = _fluid.estimateFlowDistributionActualFlowRate(
            newFontaine, Fontaine(newFontaine).TAX_DISTRIBUTION_POOL(), taxFlowRate
        );

        assertEq(
            _fluid.getFlowDistributionFlowRate(newFontaine, Fontaine(newFontaine).TAX_DISTRIBUTION_POOL()),
            actualTaxFlowRate,
            "incorrect tax flowrate"
        );

        assertEq(_fluid.getFlowRate(newFontaine, user), unlockFlowRate, "incorrect unlock flowrate");
    }

    function testTerminateUnlock(
        uint128 unlockPeriod,
        uint256 unlockAmount,
        uint128 terminationDelay,
        uint128 tooEarlyDelay
    ) external {
        unlockPeriod = uint128(bound(unlockPeriod, _MIN_UNLOCK_PERIOD, _MAX_UNLOCK_PERIOD));
        unlockAmount = bound(unlockAmount, 1_000e18, 100_000e18);
        terminationDelay = uint128(bound(terminationDelay, 4 hours, 1 days));
        tooEarlyDelay = uint128(bound(tooEarlyDelay, 25 hours, unlockPeriod));

        _helperBobStaking();

        // Setup & Start Fontaine
        (int96 taxFlowRate, int96 unlockFlowRate) = _helperCalculateUnlockFlowRates(unlockAmount, unlockPeriod);
        address newFontaine = _helperCreateFontaine();
        address user = makeAddr("user");
        vm.prank(FLUID_TREASURY);
        _fluid.transfer(newFontaine, unlockAmount);
        IFontaine(newFontaine).initialize(user, unlockFlowRate, taxFlowRate, unlockPeriod);

        uint256 expectedTaxBalance = uint96(taxFlowRate) * unlockPeriod;
        uint256 expectedUserBalance = uint96(unlockFlowRate) * unlockPeriod;

        uint256 tooEarlyEndDate = block.timestamp + unlockPeriod - tooEarlyDelay;
        uint256 earlyEndDate = block.timestamp + unlockPeriod - terminationDelay;

        vm.warp(tooEarlyEndDate);
        vm.expectRevert(IFontaine.TOO_EARLY_TO_TERMINATE_UNLOCK.selector);
        IFontaine(newFontaine).terminateUnlock();

        vm.warp(earlyEndDate);
        IFontaine(newFontaine).terminateUnlock();

        assertApproxEqAbs(
            bobLocker.getAvailableBalance(), expectedTaxBalance, expectedTaxBalance * 2 / 100, "invalid tax amount"
        );
        assertApproxEqAbs(
            _fluid.balanceOf(user), expectedUserBalance, expectedUserBalance * 2 / 100, "invalid unlocked amount"
        );
    }

    function testAccidentalStreamCancel() external {
        uint128 unlockPeriod = _MAX_UNLOCK_PERIOD;
        uint256 unlockAmount = 10 ether;

        // Setup & Start Fontaine
        address newFontaine = _helperCreateFontaine();

        vm.prank(FLUID_TREASURY);
        _fluid.transfer(newFontaine, unlockAmount);

        address user = makeAddr("user");
        (int96 unlockFlowRate, int96 taxFlowRate) = calculateVestUnlockFlowRates(unlockAmount, unlockPeriod);
        assertEq(taxFlowRate, 0, "tax flow rate shall be 0");

        IFontaine(newFontaine).initialize(user, unlockFlowRate, taxFlowRate, unlockPeriod);

        uint256 halfwayUnlockPeriod = block.timestamp + 270 days;
        uint256 afterEndUnlockPeriod = block.timestamp + 542 days;

        vm.warp(halfwayUnlockPeriod);

        assertGt(_fluid.getFlowRate(newFontaine, user), 1, "there should be a flowrate");

        vm.startPrank(user);
        _fluid.deleteFlow(newFontaine, user);
        vm.stopPrank();

        assertEq(_fluid.getFlowRate(newFontaine, user), 0, "incorrect unlock flowrate");

        uint256 currentFontaineBalance = _fluid.balanceOf(newFontaine);

        vm.warp(afterEndUnlockPeriod);

        vm.prank(user);
        IFontaine(newFontaine).terminateUnlock();

        assertEq(_fluid.balanceOf(newFontaine), 0);
    }

    function _helperBobStaking() internal {
        _helperFundLocker(address(bobLocker), 10_000e18);
        vm.prank(BOB);
        bobLocker.stake();
    }

    function _helperCreateFontaine() internal returns (address newFontaine) {
        newFontaine = address(new BeaconProxy(address(_fontaineBeacon), ""));
    }

    function _helperCalculateUnlockFlowRates(uint256 amountToUnlock, uint128 unlockPeriod)
        internal
        pure
        returns (int96 taxFlowRate, int96 unlockFlowRate)
    {
        int96 globalFlowRate = int256(amountToUnlock / unlockPeriod).toInt96();

        uint256 unlockingPercentageBP =
            (2_000 + ((8_000 * Math.sqrt(unlockPeriod * _SCALER)) / Math.sqrt(540 days * _SCALER)));

        unlockFlowRate = (globalFlowRate * int256(unlockingPercentageBP)).toInt96() / int256(_BP_DENOMINATOR).toInt96();
        taxFlowRate = globalFlowRate - unlockFlowRate;
    }
}

contract FontaineLayoutTest is Fontaine {
    constructor() Fontaine(ISuperToken(address(0)), ISuperfluidPool(address(0))) { }

    function testStorageLayout() external pure {
        uint256 slot;
        uint256 offset;

        // Fontaine storage

        assembly {
            slot := recipient.slot
            offset := recipient.offset
        }
        require(slot == 0 && offset == 0, "recipient changed location");

        // private state : _taxFlowRate
        // slot = 0 - offset = 20

        // private state : _unlockFlowRate
        // slot = 1 - offset = 0

        assembly {
            slot := endDate.slot
            offset := endDate.offset
        }
        require(slot == 1 && offset == 12, "stakingUnlocksAt changed location");
    }
}
