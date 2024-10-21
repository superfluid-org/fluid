// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { SuperfluidFrameworkDeployer } from
    "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import { ERC1820RegistryCompiled } from
    "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { ISuperfluidPool } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { TestToken } from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import { SuperToken } from "@superfluid-finance/ethereum-contracts/contracts/superfluid/SuperToken.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { EPProgramManager } from "../src/EPProgramManager.sol";
import { FluidLocker } from "../src/FluidLocker.sol";
import { FluidLockerFactory } from "../src/FluidLockerFactory.sol";
import { Fontaine } from "../src/Fontaine.sol";
import { PenaltyManager } from "../src/PenaltyManager.sol";

import { deployAll } from "../script/Deploy.s.sol";

using SuperTokenV1Library for SuperToken;

contract SFTest is Test {
    uint256 public constant INITIAL_BALANCE = 10000 ether;
    uint256 public constant FLUID_SUPPLY = 1_000_000_000 ether;

    SuperfluidFrameworkDeployer.Framework internal _sf;
    SuperfluidFrameworkDeployer internal _deployer;

    address public constant ADMIN = address(0x420);
    address public constant ALICE = address(0x1);
    address public constant BOB = address(0x2);
    address public constant CAROL = address(0x3);
    address public constant FLUID_TREASURY = address(0x4);
    address[] internal TEST_ACCOUNTS = [ADMIN, FLUID_TREASURY, ALICE, BOB, CAROL];

    TestToken internal _fluidUnderlying;
    SuperToken internal _fluidSuperToken;

    EPProgramManager internal _programManager;
    FluidLocker internal _fluidLockerLogic;
    Fontaine internal _fontaineLogic;
    FluidLockerFactory internal _fluidLockerFactory;
    PenaltyManager internal _penaltyManager;

    function setUp() public virtual {
        // Superfluid Protocol Deployment Start
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        _deployer = new SuperfluidFrameworkDeployer();
        _deployer.deployTestFramework();
        _sf = _deployer.getFramework();

        (_fluidUnderlying, _fluidSuperToken) =
            _deployer.deployWrapperSuperToken("Super FLUID", "FLUIDx", 18, type(uint256).max, address(0));

        // Superfluid Protocol Deployment End

        // Mint tokens for test accounts
        for (uint256 i; i < TEST_ACCOUNTS.length; ++i) {
            vm.startPrank(TEST_ACCOUNTS[i]);
            vm.deal(TEST_ACCOUNTS[i], INITIAL_BALANCE);
            vm.stopPrank();
        }

        vm.startPrank(FLUID_TREASURY);
        _fluidUnderlying.mint(FLUID_TREASURY, FLUID_SUPPLY);
        _fluidUnderlying.approve(address(_fluidSuperToken), FLUID_SUPPLY);
        _fluidSuperToken.upgrade(FLUID_SUPPLY);
        vm.stopPrank();

        // FLUID Contracts Deployment Start
        vm.startPrank(ADMIN);

        (
            address programManagerAddress,
            address penaltyManagerAddress,
            address lockerFactoryAddress,
            address lockerLogicAddress,
            address fontaineLogicAddress
        ) = deployAll(_fluidSuperToken, ADMIN);

        _programManager = EPProgramManager(programManagerAddress);
        _penaltyManager = PenaltyManager(penaltyManagerAddress);
        _fluidLockerFactory = FluidLockerFactory(lockerFactoryAddress);
        _fluidLockerLogic = FluidLocker(lockerLogicAddress);
        _fontaineLogic = Fontaine(fontaineLogicAddress);

        vm.stopPrank();

        // FLUID Contracts Deployment End
    }

    function _helperCreateProgram(uint256 pId, address admin, address signer) internal returns (ISuperfluidPool pool) {
        pool = _programManager.createProgram(pId, admin, signer, _fluidSuperToken);
    }
}
