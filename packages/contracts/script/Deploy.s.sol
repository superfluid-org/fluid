// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
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

function deployAll(ISuperToken fluid, address owner)
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
    FluidLockerFactory lockerFactory =
        new FluidLockerFactory(address(fluidLockerImpl), IPenaltyManager(address(penaltyManager)));
    lockerFactoryAddress = address(lockerFactory);

    // Sets the FluidLockerFactory address in the PenaltyManager
    penaltyManager.setLockerFactory(address(lockerFactory));
}

// forge script script/Deploy.s.sol:DeployScript --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv
contract DeployScript is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        ISuperToken fluid = ISuperToken(vm.envAddress("FLUID_ADDRESS"));

        vm.startBroadcast(deployerPrivateKey);
        deployAll(fluid, vm.addr(deployerPrivateKey));
    }
}
