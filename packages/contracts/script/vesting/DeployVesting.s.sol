// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, console2 } from "forge-std/Script.sol";

import {
    ISuperfluid,
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

// forge script script/DeployVesting.s.sol:DeployVestingScript --ffi --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvvv
contract DeployVestingScript is Script {
    function setUp() public { }

    function run() public {
        _showGitRevision();

        // Deployer settings
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Deployment parameters
        address vestingScheduler = vm.envAddress("VESTING_SCHEDULER_ADDRESS");
        address supToken = vm.envAddress("FLUID_ADDRESS");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address governor = vm.envAddress("GOVERNOR_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        SupVestingFactory supVestingFactory = new SupVestingFactory(vestingScheduler, supToken, treasury, governor);
    }

    function _showGitRevision() internal {
        string[] memory inputs = new string[](2);
        inputs[0] = "../tasks/show-git-rev.sh";
        inputs[1] = "forge_ffi_mode";
        try vm.ffi(inputs) returns (bytes memory res) {
            console2.log("GIT REVISION :");
            console2.log(string(res));
        } catch {
            console2.log("!! _showGitRevision: FFI not enabled");
        }
    }
}
