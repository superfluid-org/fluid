// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, console2 } from "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin-v5/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {
    ISuperfluid,
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import { IEPProgramManager } from "../src/interfaces/IEPProgramManager.sol";
import { FluidEPProgramManager } from "../src/FluidEPProgramManager.sol";
import { FluidLocker } from "../src/FluidLocker.sol";
import { FluidLockerFactory } from "../src/FluidLockerFactory.sol";
import { Fontaine } from "../src/Fontaine.sol";
import { StakingRewardController, IStakingRewardController } from "../src/StakingRewardController.sol";

struct DeploySettings {
    ISuperToken fluid;
    address governor;
    address owner;
    address treasury;
    bool factoryPauseStatus;
    bool unlockStatus;
}

function deployFontaineBeacon(ISuperToken fluid, ISuperfluidPool taxDistributionPool, address governor)
    returns (address fontaineLogicAddress, address fontaineBeaconAddress)
{
    // Deploy the Fontaine Implementation and associated Beacon contract
    fontaineLogicAddress = address(new Fontaine(fluid, taxDistributionPool));
    UpgradeableBeacon fontaineBeacon = new UpgradeableBeacon(fontaineLogicAddress);
    fontaineBeaconAddress = address(fontaineBeacon);

    // Transfer Fontaine Beacon ownership to the governor
    fontaineBeacon.transferOwnership(governor);
}

function deployLockerBeacon(
    DeploySettings memory settings,
    ISuperfluidPool taxDistributionPool,
    address programManagerAddress,
    address stakingRewardControllerAddress,
    address fontaineBeaconAddress
) returns (address lockerLogicAddress, address lockerBeaconAddress) {
    // Deploy the Fluid Locker Implementation and associated Beacon contract
    lockerLogicAddress = address(
        new FluidLocker(
            settings.fluid,
            taxDistributionPool,
            IEPProgramManager(programManagerAddress),
            IStakingRewardController(stakingRewardControllerAddress),
            fontaineBeaconAddress,
            settings.governor,
            settings.unlockStatus
        )
    );
    UpgradeableBeacon lockerBeacon = new UpgradeableBeacon(lockerLogicAddress);
    lockerBeaconAddress = address(lockerBeacon);

    // Transfer Locker Beacon ownership to the governor
    lockerBeacon.transferOwnership(settings.governor);
}

function deployAll(DeploySettings memory settings)
    returns (
        address programManagerAddress,
        address stakingRewardControllerAddress,
        address lockerFactoryAddress,
        address lockerLogicAddress,
        address lockerBeaconAddress,
        address fontaineLogicAddress,
        address fontaineBeaconAddress
    )
{
    // Deploy Penalty Manager
    StakingRewardController stakingRewardController = new StakingRewardController(settings.owner, settings.fluid);
    stakingRewardControllerAddress = address(stakingRewardController);

    // Deploy Ecosystem Partner Program Manager
    FluidEPProgramManager programManager = new FluidEPProgramManager(
        settings.owner, settings.treasury, IStakingRewardController(stakingRewardControllerAddress)
    );
    programManagerAddress = address(programManager);

    // Deploy the Fontaine Implementation and associated Beacon contract
    (fontaineLogicAddress, fontaineBeaconAddress) =
        deployFontaineBeacon(settings.fluid, stakingRewardController.TAX_DISTRIBUTION_POOL(), settings.governor);

    // Deploy the Fluid Locker Implementation and associated Beacon contract
    (lockerLogicAddress, lockerBeaconAddress) = deployLockerBeacon(
        settings,
        stakingRewardController.TAX_DISTRIBUTION_POOL(),
        programManagerAddress,
        stakingRewardControllerAddress,
        fontaineBeaconAddress
    );

    // Deploy the Fluid Locker Factory contract
    FluidLockerFactory lockerFactoryLogic = new FluidLockerFactory(
        lockerBeaconAddress, IStakingRewardController(address(stakingRewardController)), settings.factoryPauseStatus
    );

    ERC1967Proxy lockerFactoryProxy = new ERC1967Proxy(
        address(lockerFactoryLogic), abi.encodeWithSelector(FluidLockerFactory.initialize.selector, settings.governor)
    );

    FluidLockerFactory lockerFactory = FluidLockerFactory(address(lockerFactoryProxy));
    lockerFactory.LOCKER_BEACON().transferOwnership(settings.governor);

    lockerFactoryAddress = address(lockerFactory);

    // Sets the FluidLockerFactory address in the StakingRewardController
    stakingRewardController.setLockerFactory(lockerFactoryAddress);

    // Sets the FluidLockerFactory address in the ProgramManager
    programManager.setLockerFactory(lockerFactoryAddress);
}

// forge script script/Deploy.s.sol:DeployScript --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv
contract DeployScript is Script {
    error GOVERNOR_IS_ZERO_ADDRESS();

    function setUp() public { }

    function run() public {
        /// FIXME Add logging for all parameters + git revision status

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        ISuperToken fluid = ISuperToken(vm.envAddress("FLUID_ADDRESS"));
        bool factoryPauseStatus = vm.envBool("PAUSE_FACTORY_LOCKER_CREATION");
        bool unlockStatus = vm.envBool("FLUID_UNLOCK_STATUS");

        // Purposedly not enforcing this at contract level in case governance decides to forfeit ownership of the contracts
        if (governor == address(0)) {
            revert GOVERNOR_IS_ZERO_ADDRESS();
        }

        DeploySettings memory settings = DeploySettings({
            fluid: fluid,
            governor: governor,
            owner: deployer,
            treasury: treasury,
            factoryPauseStatus: factoryPauseStatus,
            unlockStatus: unlockStatus
        });

        vm.startBroadcast(deployerPrivateKey);
        (
            address programManagerAddress,
            address stakingRewardControllerAddress,
            address lockerFactoryAddress,
            address lockerLogicAddress,
            address lockerBeaconAddress,
            address fontaineLogicAddress,
            address fontaineBeaconAddress
        ) = deployAll(settings);

        console2.log("FluidEPProgramManager     : deployed at %s ", programManagerAddress);
        console2.log("StakingRewardController   : deployed at %s ", stakingRewardControllerAddress);
        console2.log("FluidLocker (Logic)       : deployed at %s ", lockerLogicAddress);
        console2.log("FluidLocker (Beacon)      : deployed at %s ", lockerBeaconAddress);
        console2.log("Fontaine (Logic)          : deployed at %s ", fontaineLogicAddress);
        console2.log("Fontaine (Beacon)         : deployed at %s ", fontaineBeaconAddress);
        console2.log("FluidLockerFactory        : deployed at %s ", lockerFactoryAddress);
    }
}
