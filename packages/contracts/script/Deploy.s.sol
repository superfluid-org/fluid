// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, console2 } from "forge-std/Script.sol";

import { ERC1967Proxy } from "@openzeppelin-v5/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {
    ISuperfluid,
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import { EPProgramManager, IEPProgramManager } from "../src/EPProgramManager.sol";
import { FluidLocker } from "../src/FluidLocker.sol";
import { FluidLockerFactory } from "../src/FluidLockerFactory.sol";
import { Fontaine } from "../src/Fontaine.sol";
import { PenaltyManager, IPenaltyManager } from "../src/PenaltyManager.sol";

function deployAll(ISuperToken fluid, address governor, address owner)
    returns (
        address programManagerAddress,
        address penaltyManagerAddress,
        address lockerFactoryAddress,
        address lockerLogicAddress,
        address fontaineLogicAddress
    )
{
    // Deploy Ecosystem Partner Program Manager
    EPProgramManager programManager = new EPProgramManager();
    programManagerAddress = address(programManager);

    // Deploy Penalty Manager
    PenaltyManager penaltyManager = new PenaltyManager(owner, fluid);
    penaltyManagerAddress = address(penaltyManager);

    // Read the newly created GDA Tax Distribution Pool address
    ISuperfluidPool taxDistributionPool = penaltyManager.TAX_DISTRIBUTION_POOL();

    // Deploy the Fontaine Implementation contract
    Fontaine fontaineImpl = new Fontaine(fluid, taxDistributionPool);
    fontaineLogicAddress = address(fontaineImpl);

    // Deploy the Fluid Locker Implementation contract
    FluidLocker fluidLockerImpl = new FluidLocker(
        fluid,
        taxDistributionPool,
        IEPProgramManager(programManagerAddress),
        IPenaltyManager(penaltyManagerAddress),
        fontaineLogicAddress
    );
    lockerLogicAddress = address(fluidLockerImpl);

    // Deploy the Fluid Locker Factory contract
    FluidLockerFactory lockerFactoryLogic =
        new FluidLockerFactory(address(fluidLockerImpl), IPenaltyManager(address(penaltyManager)));

    bytes memory callData = abi.encodeWithSelector(FluidLockerFactory.initialize.selector, governor);

    ERC1967Proxy lockerFactoryProxy = new ERC1967Proxy(address(lockerFactoryLogic), callData);

    FluidLockerFactory lockerFactory = FluidLockerFactory(address(lockerFactoryProxy));
    lockerFactoryAddress = address(lockerFactory);

    // Sets the FluidLockerFactory address in the PenaltyManager
    penaltyManager.setLockerFactory(lockerFactoryAddress);
}

// forge script script/Deploy.s.sol:DeployScript --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv
contract DeployScript is Script {
    error GOVERNOR_IS_ZERO_ADDRESS();

    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address governor = vm.envAddress("GOVERNOR_ADDRESS");
        ISuperToken fluid = ISuperToken(vm.envAddress("FLUID_ADDRESS"));

        // Purposedly not enforcing this at contract level in case governance decides to forfeit ownership of the contracts
        if (governor == address(0)) {
            revert GOVERNOR_IS_ZERO_ADDRESS();
        }

        vm.startBroadcast(deployerPrivateKey);
        (
            address programManagerAddress,
            address penaltyManagerAddress,
            address lockerFactoryAddress,
            address lockerLogicAddress,
            address fontaineLogicAddress
        ) = deployAll(fluid, governor, vm.addr(deployerPrivateKey));

        console2.log("EPProgramManager      : deployed at %s ", programManagerAddress);
        console2.log("PenaltyManager        : deployed at %s ", penaltyManagerAddress);
        console2.log("FluidLocker (Logic)   : deployed at %s ", lockerLogicAddress);
        console2.log("Fontaine (Logic)      : deployed at %s ", fontaineLogicAddress);
        console2.log("FluidLockerFactory    : deployed at %s ", lockerFactoryAddress);
    }
}
