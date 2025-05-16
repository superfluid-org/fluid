// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

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
    uint128 internal constant _MAX_UNLOCK_PERIOD = 365 days;
    uint256 internal constant _EARLY_END_DELAY = 1 days;
    uint256 internal constant _BP_DENOMINATOR = 10_000;
    uint256 internal constant _SCALER = 1e18;

    IFluidLocker public bobLocker;
    IFluidLocker public carolLocker;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(BOB);
        bobLocker = IFluidLocker(_fluidLockerFactory.createLockerContract());

        vm.prank(CAROL);
        carolLocker = IFluidLocker(_fluidLockerFactory.createLockerContract());
    }

    function testInitialize(uint128 unlockPeriod, uint256 unlockAmount) external {
        // Bound Fuzz Parameters
        unlockPeriod = uint128(bound(unlockPeriod, _MIN_UNLOCK_PERIOD, _MAX_UNLOCK_PERIOD));
        unlockAmount = bound(unlockAmount, 1e18, 100_000_000e18);

        // Setup Stakers and Liquidity Providers
        _helperLockerStake(address(bobLocker));
        _helperLockerProvideLiquidity(address(carolLocker));

        // Calculate the flow rates based on the unlock amount and period
        (int96 stakerFlowRate, int96 providerFlowRate, int96 unlockFlowRate) =
            _helperCalculateUnlockFlowRates(unlockAmount, unlockPeriod);

        // Create and fund the Fontaine
        address newFontaine = _helperCreateFontaine();
        vm.prank(FLUID_TREASURY);
        _fluid.transfer(newFontaine, unlockAmount);

        (, int96 actualStakerFlowRate) = _fluid.estimateFlowDistributionActualFlowRate(
            newFontaine, Fontaine(newFontaine).STAKER_DISTRIBUTION_POOL(), stakerFlowRate
        );
        (, int96 actualProviderFlowRate) = _fluid.estimateFlowDistributionActualFlowRate(
            newFontaine, Fontaine(newFontaine).PROVIDER_DISTRIBUTION_POOL(), providerFlowRate
        );

        // Initialize the Fontaine
        address user = makeAddr("user");
        IFontaine(newFontaine).initialize(user, unlockFlowRate, providerFlowRate, stakerFlowRate, unlockPeriod);

        // Assert the Fontaine is initialized correctly
        assertEq(Fontaine(newFontaine).recipient(), user, "recipient incorrect");
        assertEq(Fontaine(newFontaine).endDate(), uint128(block.timestamp) + unlockPeriod, "end date incorrect");
        assertEq(Fontaine(newFontaine).unlockFlowRate(), uint96(unlockFlowRate), "unlock flow rate incorrect");
        assertEq(Fontaine(newFontaine).stakerFlowRate(), uint96(stakerFlowRate), "staker flow rate incorrect");
        assertEq(Fontaine(newFontaine).providerFlowRate(), uint96(providerFlowRate), "provider flow rate incorrect");
        assertEq(_fluid.getFlowRate(newFontaine, user), unlockFlowRate, "incorrect unlock flowrate");
        assertEq(
            _fluid.getFlowDistributionFlowRate(newFontaine, Fontaine(newFontaine).STAKER_DISTRIBUTION_POOL()),
            actualStakerFlowRate,
            "incorrect staker flowrate"
        );
        assertEq(
            _fluid.getFlowDistributionFlowRate(newFontaine, Fontaine(newFontaine).PROVIDER_DISTRIBUTION_POOL()),
            actualProviderFlowRate,
            "incorrect provider flowrate"
        );
    }

    function testTerminateUnlock(
        uint128 unlockPeriod,
        uint256 unlockAmount,
        uint128 terminationDelay,
        uint128 tooEarlyDelay
    ) external {
        // Bound Fuzz Parameters
        /// NOTE : issues will arise if the unlock amount is too low (less than 10 SUP)
        unlockAmount = bound(unlockAmount, 10e18, 100_000_000e18);
        unlockPeriod = uint128(bound(unlockPeriod, _MIN_UNLOCK_PERIOD, _MAX_UNLOCK_PERIOD));
        terminationDelay = uint128(bound(terminationDelay, 4 hours, _EARLY_END_DELAY));
        tooEarlyDelay = uint128(bound(tooEarlyDelay, 25 hours, unlockPeriod));

        // Setup Stakers and Liquidity Providers
        _helperLockerStake(address(bobLocker));
        _helperLockerProvideLiquidity(address(carolLocker));

        // Setup & Start Fontaine
        (int96 stakerFlowRate, int96 providerFlowRate, int96 unlockFlowRate) =
            _helperCalculateUnlockFlowRates(unlockAmount, unlockPeriod);

        uint256 expectedProviderBalance = carolLocker.getAvailableBalance() + (uint96(providerFlowRate) * unlockPeriod);
        uint256 expectedStakerBalance = bobLocker.getAvailableBalance() + (uint96(stakerFlowRate) * unlockPeriod);

        // Create and fund the Fontaine
        address newFontaine = _helperCreateFontaine();
        vm.prank(FLUID_TREASURY);
        _fluid.transfer(newFontaine, unlockAmount);

        // Initialize the Fontaine
        IFontaine(newFontaine).initialize(
            makeAddr("user"), unlockFlowRate, providerFlowRate, stakerFlowRate, unlockPeriod
        );

        uint256 earlyEndDate = block.timestamp + unlockPeriod - terminationDelay;

        vm.warp(block.timestamp + unlockPeriod - tooEarlyDelay);
        vm.expectRevert(IFontaine.TOO_EARLY_TO_TERMINATE_UNLOCK.selector);
        IFontaine(newFontaine).terminateUnlock();

        vm.warp(earlyEndDate);
        IFontaine(newFontaine).terminateUnlock();

        assertApproxEqAbs(
            bobLocker.getAvailableBalance(),
            expectedStakerBalance,
            expectedStakerBalance * 10 / 100,
            "Staker balance incorrect"
        );

        assertApproxEqAbs(
            carolLocker.getAvailableBalance(),
            expectedProviderBalance,
            expectedProviderBalance * 10 / 100,
            "Provider balance incorrect"
        );

        assertApproxEqAbs(
            _fluid.balanceOf(makeAddr("user")),
            uint96(unlockFlowRate) * unlockPeriod,
            (uint96(unlockFlowRate) * unlockPeriod) * 10 / 100,
            "Unlocked amount incorrect"
        );
    }

    function testTerminateUnlock_noStaker(
        uint128 unlockPeriod,
        uint256 unlockAmount,
        uint128 terminationDelay,
        uint128 tooEarlyDelay
    ) external {
        // Bound Fuzz Parameters
        /// NOTE : issues will arise if the unlock amount is too low (less than 10 SUP)
        unlockAmount = bound(unlockAmount, 10e18, 100_000_000e18);
        unlockPeriod = uint128(bound(unlockPeriod, _MIN_UNLOCK_PERIOD, _MAX_UNLOCK_PERIOD));
        terminationDelay = uint128(bound(terminationDelay, 4 hours, _EARLY_END_DELAY));
        tooEarlyDelay = uint128(bound(tooEarlyDelay, 25 hours, unlockPeriod));

        // Setup Stakers and Liquidity Providers
        _helperLockerStake(address(bobLocker));
        _helperLockerProvideLiquidity(address(carolLocker));

        (int96 stakerFlowRate, int96 providerFlowRate, int96 unlockFlowRate) =
            _helperCalculateUnlockFlowRates(unlockAmount, unlockPeriod);

        uint256 expectedStakerBalance =
            _fluid.balanceOf(address(bobLocker)) + (uint96(stakerFlowRate) * (unlockPeriod - terminationDelay));

        // Create and fund the Fontaine
        address newFontaine = _helperCreateFontaine();
        vm.prank(FLUID_TREASURY);
        _fluid.transfer(newFontaine, unlockAmount);

        // Initialize the Fontaine
        IFontaine(newFontaine).initialize(
            makeAddr("user"), unlockFlowRate, providerFlowRate, stakerFlowRate, unlockPeriod
        );

        uint256 earlyEndDate = block.timestamp + unlockPeriod - terminationDelay;

        vm.warp(block.timestamp + unlockPeriod - tooEarlyDelay);
        vm.expectRevert(IFontaine.TOO_EARLY_TO_TERMINATE_UNLOCK.selector);
        IFontaine(newFontaine).terminateUnlock();

        vm.warp(earlyEndDate);

        _helperLockerUnstake(address(bobLocker));
        IFontaine(newFontaine).terminateUnlock();

        assertApproxEqAbs(
            _fluid.balanceOf(address(bobLocker)),
            expectedStakerBalance,
            expectedStakerBalance * 10 / 100,
            "Staker balance incorrect"
        );

        assertApproxEqAbs(
            _fluid.balanceOf(makeAddr("user")),
            (uint96(unlockFlowRate) * unlockPeriod) + (uint96(stakerFlowRate) * terminationDelay),
            _fluid.balanceOf(makeAddr("user")) * 10 / 100,
            "Unlocked amount incorrect"
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

        // Calculate the tax allocation split between provider and staker
        (, uint256 providerAllocation) = _stakingRewardController.getTaxAllocation();

        int96 providerFlowRate =
            (taxFlowRate * int256(providerAllocation).toInt96()) / int256(_BP_DENOMINATOR).toInt96();
        int96 stakerFlowRate = taxFlowRate - providerFlowRate;

        assertEq(taxFlowRate, 0, "tax flow rate shall be 0");
        assertEq(stakerFlowRate, 0, "staker flow rate shall be 0");
        assertEq(providerFlowRate, 0, "provider flow rate shall be 0");

        IFontaine(newFontaine).initialize(user, unlockFlowRate, providerFlowRate, stakerFlowRate, unlockPeriod);

        uint256 halfwayUnlockPeriod = block.timestamp + 270 days;
        uint256 afterEndUnlockPeriod = block.timestamp + 542 days;

        vm.warp(halfwayUnlockPeriod);

        assertGt(_fluid.getFlowRate(newFontaine, user), 1, "there should be a flowrate");

        vm.startPrank(user);
        _fluid.deleteFlow(newFontaine, user);
        vm.stopPrank();

        assertEq(_fluid.getFlowRate(newFontaine, user), 0, "incorrect unlock flowrate");

        vm.warp(afterEndUnlockPeriod);

        vm.prank(user);
        IFontaine(newFontaine).terminateUnlock();

        assertEq(_fluid.balanceOf(newFontaine), 0);
    }

    //      __  __     __                   ______                 __  _
    //     / / / /__  / /___  ___  _____   / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / /_/ / _ \/ / __ \/ _ \/ ___/  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / __  /  __/ / /_/ /  __/ /     / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_/ /_/\___/_/ .___/\___/_/     /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/
    //              /_/

    function _helperCreateFontaine() internal returns (address newFontaine) {
        newFontaine = address(new BeaconProxy(address(_fontaineBeacon), ""));
    }

    function _helperCalculateUnlockFlowRates(uint256 amountToUnlock, uint128 unlockPeriod)
        internal
        view
        returns (int96 stakerFlowRate, int96 providerFlowRate, int96 unlockFlowRate)
    {
        int96 globalFlowRate = int256(amountToUnlock / unlockPeriod).toInt96();

        uint256 unlockingPercentageBP =
            (2_000 + ((8_000 * Math.sqrt(unlockPeriod * _SCALER)) / Math.sqrt(_MAX_UNLOCK_PERIOD * _SCALER)));

        unlockFlowRate = (globalFlowRate * int256(unlockingPercentageBP)).toInt96() / int256(_BP_DENOMINATOR).toInt96();
        int96 taxFlowRate = globalFlowRate - unlockFlowRate;

        // Calculate the tax allocation split between provider and staker
        (, uint256 providerAllocation) = _stakingRewardController.getTaxAllocation();

        providerFlowRate = (taxFlowRate * int256(providerAllocation).toInt96()) / int256(_BP_DENOMINATOR).toInt96();
        stakerFlowRate = taxFlowRate - providerFlowRate;
    }
}

contract FontaineLayoutTest is Fontaine {
    constructor() Fontaine(ISuperToken(address(0)), ISuperfluidPool(address(0)), ISuperfluidPool(address(0))) { }

    function testStorageLayout() external pure {
        uint256 slot;
        uint256 offset;

        // Fontaine storage

        assembly {
            slot := recipient.slot
            offset := recipient.offset
        }
        require(slot == 0 && offset == 0, "recipient changed location");

        assembly {
            slot := stakerFlowRate.slot
            offset := stakerFlowRate.offset
        }
        require(slot == 0 && offset == 20, "stakerFlowRate changed location");

        assembly {
            slot := unlockFlowRate.slot
            offset := unlockFlowRate.offset
        }
        require(slot == 1 && offset == 0, "unlockFlowRate changed location");

        assembly {
            slot := endDate.slot
            offset := endDate.offset
        }
        require(slot == 1 && offset == 12, "endDate changed location");

        assembly {
            slot := providerFlowRate.slot
            offset := providerFlowRate.offset
        }
        require(slot == 2 && offset == 0, "providerFlowRate changed location");
    }
}
