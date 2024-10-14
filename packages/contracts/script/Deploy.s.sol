// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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

// forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast --verify -vvvv
contract DeployScript is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ISuperToken fluid = ISuperToken(vm.envAddress("FLUID_ADDRESS"));

        // Deploy Ecosystem Partner Program Manager
        EPProgramManager programManager = new EPProgramManager();

        // Deploy Penalty Manager
        PenaltyManager penaltyManager = new PenaltyManager(vm.addr(deployerPrivateKey), fluid);

        // Read the newly created GDA Penalty Pool address
        ISuperfluidPool penaltyDrainingPool = penaltyManager.PENALTY_DRAINING_POOL();

        // Deploy the Fluid Locker Implementation contract
        FluidLocker fluidLockerImpl =
            new FluidLocker(fluid, penaltyDrainingPool, IEPProgramManager(address(programManager)));

        // Deploy the Fontaine Implementation contract
        Fontaine fontaineImpl = new Fontaine(fluid, penaltyDrainingPool);

        // Deploy the Fluid Locker Factory contract
        FluidLockerFactory lockerFactory = new FluidLockerFactory(
            address(fluidLockerImpl), address(fontaineImpl), IPenaltyManager(address(penaltyManager))
        );

        // Sets the FluidLockerFactory address in the PenaltyManager
        penaltyManager.setLockerFactory(address(lockerFactory));
    }
}
