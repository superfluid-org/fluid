// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Script } from "forge-std/Script.sol";
import {
    ISuperfluid,
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import { IEPProgramManager } from "../../src/EPProgramManager.sol";

// forge script script/CreateProgram.s.sol:CreateProgram --rpc-url $RPC_URL --broadcast --verify -vvvv
contract CreateProgram is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        ISuperToken fluid = ISuperToken(vm.envAddress("FLUID_ADDRESS"));
        address signer = vm.envAddress("STACK_SIGNER_ADDRESS");
        IEPProgramManager programManager = IEPProgramManager(vm.envAddress("EP_PROGRAM_MANAGER_ADDRESS"));
        uint8 programId = uint8(vm.envUint("PROGRAM_ID"));

        programManager.createProgram(programId, vm.addr(deployerPrivateKey), signer, fluid);
    }
}
