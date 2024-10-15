// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol";

// import { SFTest } from "./SFTest.t.sol";
// import { AlfaBurningProgram } from "../src/AlfaBurningProgram.sol";
// import { DistributorBase } from "../src/DistributorBase.sol";
// import { EmissionRegulator } from "../src/EmissionRegulator.sol";

// import { IFanToken } from "../src/interfaces/IFanToken.sol";
// import { IEmissionRegulator } from "../src/interfaces/IEmissionRegulator.sol";
// import {
//     ISuperfluid,
//     ISuperTokenFactory,
//     ISuperToken,
//     ISuperfluidPool
// } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
// import { PureSuperToken } from "@superfluid-finance/ethereum-contracts/contracts/tokens/PureSuperToken.sol";
// import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

// using SuperTokenV1Library for ISuperToken;

// contract AlfaBurningProgramTest is SFTest {
//     AlfaBurningProgram private _burningProgram;
//     EmissionRegulator private _regulator;
//     ISuperToken private _afToken;
//     uint256 private fanTokenDecimals;

//     uint256 private constant _PROGRAM_DURATION = 180 days;

//     function setUp() public override {
//         super.setUp();

//         fanTokenDecimals = fanToken.decimals();

//         // deal some FAN to ALICE for testing
//         _mintFanTokens(ALICE, 100_000_000 * (10 ** fanTokenDecimals));

//         _regulator = new EmissionRegulator();

//         _afToken = _deployPureSuperToken(_sf.host, "AlfaFrens", "AF", 100_000_000 ether);

//         _burningProgram = new AlfaBurningProgram(
//             _sf.host, _afToken, IFanToken(fanToken), IEmissionRegulator(_regulator), _PROGRAM_DURATION
//         );

//         fanToken.reinitialize(address(_burningProgram));
//         _afToken.transfer(address(_burningProgram), 100_000_000 ether);
//     }

//     function testInstantRedeem(uint256 alfaAmount) external {
//         alfaAmount = bound(alfaAmount, 1 * (10 ** fanTokenDecimals), 50_000_000 * (10 ** fanTokenDecimals));

//         uint256 aliceAlfaBalanceBefore = fanToken.balanceOf(ALICE);
//         uint256 aliceAFBalanceBefore = _afToken.balanceOf(ALICE);

//         vm.prank(ALICE);
//         _burningProgram.instantRedeem(alfaAmount);

//         uint256 aliceAlfaBalanceAfter = fanToken.balanceOf(ALICE);
//         uint256 aliceAFBalanceAfter = _afToken.balanceOf(ALICE);

//         assertEq(
//             aliceAlfaBalanceAfter,
//             aliceAlfaBalanceBefore - alfaAmount,
//             "testInstantRedeem: FanToken balance did not update"
//         );
//         assertEq(
//             aliceAFBalanceAfter,
//             aliceAFBalanceBefore + _regulator.getAlfaToAFRatio(alfaAmount),
//             "testInstantRedeem: AF balance did not update"
//         );
//     }

//     function testStreamedRedeem(uint256 alfaAmount) external {
//         alfaAmount = bound(alfaAmount, 1 * (10 ** fanTokenDecimals), 50_000_000 * (10 ** fanTokenDecimals));

//         ISuperfluidPool emissionPool = _burningProgram.emissionPool();

//         uint256 aliceAlfaBalanceBefore = fanToken.balanceOf(ALICE);
//         uint256 alicePoolUnitsBefore = emissionPool.getUnits(ALICE);

//         vm.prank(ALICE);
//         _burningProgram.streamedRedeem(alfaAmount);

//         uint256 aliceAlfaBalanceAfter = fanToken.balanceOf(ALICE);
//         uint256 alicePoolUnitsAfter = emissionPool.getUnits(ALICE);

//         assertEq(
//             aliceAlfaBalanceAfter,
//             aliceAlfaBalanceBefore - alfaAmount,
//             "testStreamedRedeem: FanToken balance did not update"
//         );
//         assertEq(
//             alicePoolUnitsAfter,
//             alicePoolUnitsBefore + _regulator.getAlfaToAFEmissionUnits(alfaAmount),
//             "testStreamedRedeem: Pool Units did not update"
//         );
//     }

//     function testProgramEnded(uint256 alfaAmount, uint256 timestamp) external {
//         alfaAmount = bound(alfaAmount, 1 * (10 ** fanTokenDecimals), 50_000_000 * (10 ** fanTokenDecimals));

//         timestamp = bound(timestamp, block.timestamp + _PROGRAM_DURATION + 1, block.timestamp + 36500 days);

//         vm.warp(timestamp);

//         vm.startPrank(ALICE);
//         vm.expectRevert(DistributorBase.PROGRAM_HAS_ENDED.selector);
//         _burningProgram.instantRedeem(alfaAmount);

//         vm.expectRevert(DistributorBase.PROGRAM_HAS_ENDED.selector);
//         _burningProgram.streamedRedeem(alfaAmount);
//         vm.stopPrank();
//     }

//     function testStartFlow(uint256 alfaAmount) external {
//         alfaAmount = bound(alfaAmount, 1 * (10 ** fanTokenDecimals), 50_000_000 * (10 ** fanTokenDecimals));

//         vm.prank(ALICE);
//         _burningProgram.streamedRedeem(alfaAmount);

//         ISuperfluidPool emissionPool = _burningProgram.emissionPool();

//         int96 flowBefore = emissionPool.getMemberFlowRate(ALICE);

//         int96 distributionFlowBefore = _afToken.getFlowDistributionFlowRate(address(_burningProgram), emissionPool);

//         _burningProgram.startFlow();

//         int96 flowAfter = emissionPool.getMemberFlowRate(ALICE);
//         int96 distributionFlowAfter = _afToken.getFlowDistributionFlowRate(address(_burningProgram), emissionPool);

//         assertGt(
//             distributionFlowAfter,
//             distributionFlowBefore,
//             "testStartFlow: distribution flow rate did not update correctly"
//         );

//         assertGt(flowAfter, flowBefore, "testStartFlow: flow rate did not update correctly");
//     }

//     function _deployPureSuperToken(ISuperfluid host, string memory name, string memory symbol, uint256 initialSupply)
//         internal
//         returns (ISuperToken pureSuperToken)
//     {
//         ISuperTokenFactory factory = host.getSuperTokenFactory();

//         PureSuperToken pureSuperTokenProxy = new PureSuperToken();
//         factory.initializeCustomSuperToken(address(pureSuperTokenProxy));
//         pureSuperTokenProxy.initialize(name, symbol, initialSupply);

//         pureSuperToken = ISuperToken(address(pureSuperTokenProxy));
//     }
// }
