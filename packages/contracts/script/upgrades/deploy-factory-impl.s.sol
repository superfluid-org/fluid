// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Script, console2 } from "forge-std/Script.sol";

import { FluidLockerFactory } from "src/FluidLockerFactory.sol";
import { IStakingRewardController } from "src/interfaces/IStakingRewardController.sol";

/*
LOCKER_BEACON_ADDRESS=0xf2880c6D68080393C1784f978417a96ab4f37c38 \
STAKING_REWARD_CONTROLLER_ADDRESS=0x9FC0Bb109F3e733Bd84B30F8D89685b0304fC018 \
forge script script/upgrades/deploy-factory-impl.s.sol:DeployFluidLockerFactoyrImplementation --ffi --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify -vvv --etherscan-api-key $BASESCAN_API_KEY
*/
contract DeployFluidLockerFactoyrImplementation is Script {
    function setUp() public { }

    function run() public {
        _showGitRevision();

        address lockerBeaconAddress = vm.envAddress("LOCKER_BEACON_ADDRESS");
        address stakingRewardControllerAddress = vm.envAddress("STAKING_REWARD_CONTROLLER_ADDRESS");

        // Deployer settings
        uint256 deployerPrivKey = vm.envOr("PRIVATE_KEY", uint256(0));

        if (deployerPrivKey != 0) {
            vm.startBroadcast(deployerPrivKey);
        } else {
            vm.startBroadcast();
        }

        console2.log("LOCKER_BEACON_ADDRESS=%s", lockerBeaconAddress);
        console2.log("STAKING_REWARD_CONTROLLER_ADDRESS %s", stakingRewardControllerAddress);

        FluidLockerFactory fluidLockerFactory =
            new FluidLockerFactory(lockerBeaconAddress, IStakingRewardController(stakingRewardControllerAddress), false);
        console2.log("FluidLockerFactory implementation deployed at: ", address(fluidLockerFactory));
    }

    function _showGitRevision() internal {
        string[] memory inputs = new string[](2);
        inputs[0] = "../tasks/show-git-rev.sh";
        inputs[1] = "forge_ffi_mode";
        try vm.ffi(inputs) returns (bytes memory res) {
            console2.log("GIT REVISION : %s", string(res));
        } catch {
            console2.log("!! _showGitRevision: FFI not enabled");
        }
    }
}
