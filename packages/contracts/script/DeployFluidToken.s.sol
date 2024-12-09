// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { ISuperTokenFactory } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { BridgedSuperTokenProxy } from "../src/token/BridgedSuperToken.sol";
import { OPBridgedSuperToken } from "../src/token/OPBridgedSuperToken.sol";
import { FluidToken } from "../src/token/FluidToken.sol";

/// @dev - TODO : Stealth Name and Symbol to be changed for Mainnet Deployment
string constant tokenName = "FXXXX Token";
string constant tokenSymbol = "FXXXX";
string constant superTokenName = "FXXXX Super Token";
string constant superTokenSymbol = "FXXXXx";

/// abstract base contract to avoid code duplication
abstract contract DeployFluidTokenBase is Script {
    address owner;
    uint256 initialSupply;

    function _startBroadcast() internal returns (address deployer) {
        uint256 deployerPrivKey = vm.envOr("PRIVATE_KEY", uint256(0));

        // Setup deployment account, using private key from environment variable or foundry keystore (`cast wallet`).
        if (deployerPrivKey != 0) {
            vm.startBroadcast(deployerPrivKey);
        } else {
            vm.startBroadcast();
        }

        // This is the way to get deployer address in foundry:
        (, deployer,) = vm.readCallers();
        console2.log("Deployer address", deployer);
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
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

    function _loadTokenParams(string memory tokenType) internal virtual {
        owner = vm.envAddress("OWNER");
        initialSupply = vm.envUint("INITIAL_SUPPLY");

        console.log("Deploying \"%s\" with params:", tokenType);
        console.log("  owner:", owner);
        console.log("  initialSupply:", initialSupply);
    }
}

/// deploys FLUID Token on ETH Mainnet
contract DeployL1FluidToken is DeployFluidTokenBase {
    function run() external {
        _showGitRevision();
        _loadTokenParams("FLUID Token ERC20");

        _startBroadcast();

        // since the token is permissionless and non-upgradable, the "owner" doesn't
        // own the contract, just the initial supply
        FluidToken fluid = new FluidToken(tokenName, tokenSymbol, owner, initialSupply);
        console.log("$FLUID Token contract deployed at", address(fluid));

        _stopBroadcast();
    }
}

/// deploys and initializes an instance of OPBridgedSuperTokenProxy
contract DeployOPFluidSuperToken is DeployFluidTokenBase {
    function run() external {
        _showGitRevision();
        _loadTokenParams("FLUID OP Bridged Super Token");

        _startBroadcast();

        address superTokenFactoryAddr = vm.envAddress("SUPERTOKEN_FACTORY");
        address nativeBridge = vm.envAddress("NATIVE_BRIDGE");
        address remoteToken = vm.envAddress("REMOTE_TOKEN");

        OPBridgedSuperToken proxy = new OPBridgedSuperToken(nativeBridge, remoteToken);
        proxy.initialize(
            ISuperTokenFactory(superTokenFactoryAddr), superTokenName, superTokenSymbol, owner, initialSupply
        );
        proxy.transferOwnership(owner);
        console.log("OPBridgedSuperToken deployed at", address(proxy));
        console.log("--- SuperTokenFactory: %s", superTokenFactoryAddr);
        console.log("--- NativeBridge: %s", nativeBridge);
        console.log("--- RemoteToken: %s", remoteToken);

        _stopBroadcast();
    }
}

/// deploys and initializes an instance of BridgedSuperTokenProxy
contract DeployL2FluidSuperToken is DeployFluidTokenBase {
    function run() external {
        _showGitRevision();
        _loadTokenParams("FLUID Regular Bridged Super Token");

        address superTokenFactoryAddr = vm.envAddress("SUPERTOKEN_FACTORY");

        _startBroadcast();

        BridgedSuperTokenProxy proxy = new BridgedSuperTokenProxy();
        proxy.initialize(ISuperTokenFactory(superTokenFactoryAddr), "Fluid SuperToken", "FLUIDx", owner, initialSupply);
        proxy.transferOwnership(owner);
        console.log("BridgedSuperTokenProxy deployed at", address(proxy));
        console.log("--- SuperTokenFactory: %s", superTokenFactoryAddr);

        _stopBroadcast();
    }
}
