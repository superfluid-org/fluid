// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import { ISuperTokenFactory } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { BridgedSuperTokenProxy } from "src/token/BridgedSuperToken.sol";
import { SupTokenL2 } from "src/token/SupTokenL2.sol";
import { SupToken } from "src/token/SupToken.sol";

/// @dev - TODO : Stealth Name and Symbol to be changed for Mainnet Deployment
string constant tokenName = "SXX Token";
string constant tokenSymbol = "SXX";
string constant superTokenName = "Superfluid Token";
string constant superTokenSymbol = "SUP";

/// abstract base contract to avoid code duplication
abstract contract DeploySupTokenBase is Script {
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
contract DeployL1SupToken is DeploySupTokenBase {
    function run() external {
        _showGitRevision();
        _loadTokenParams("$SUP Token ERC20");

        _startBroadcast();

        // since the token is permissionless and non-upgradable, the "owner" doesn't
        // own the contract, just the initial supply
        SupToken sup = new SupToken(tokenName, tokenSymbol, owner, initialSupply);
        console.log("$SUP Token contract deployed at", address(sup));

        _stopBroadcast();
    }
}

/// deploys and initializes an instance of OPBridgedSuperTokenProxy
contract DeployOPSupSuperToken is DeploySupTokenBase {
    function run() external {
        _showGitRevision();
        _loadTokenParams("SUP OP Bridged Super Token");

        _startBroadcast();

        address superTokenFactoryAddr = vm.envAddress("SUPERTOKEN_FACTORY");
        address nativeBridge = vm.envAddress("NATIVE_BRIDGE");
        address remoteToken = vm.envAddress("REMOTE_TOKEN");

        SupTokenL2 proxy = new SupTokenL2(nativeBridge, remoteToken);
        proxy.initialize(
            ISuperTokenFactory(superTokenFactoryAddr), superTokenName, superTokenSymbol, owner, initialSupply
        );
        proxy.transferOwnership(owner);
        console.log("$SUP OPBridgedSuperToken deployed at", address(proxy));
        console.log("--- SuperTokenFactory: %s", superTokenFactoryAddr);
        console.log("--- NativeBridge: %s", nativeBridge);
        console.log("--- RemoteToken: %s", remoteToken);

        _stopBroadcast();
    }
}

/// deploys and initializes an instance of BridgedSuperTokenProxy
contract DeployL2SupSuperToken is DeploySupTokenBase {
    function run() external {
        _showGitRevision();
        _loadTokenParams("SUP Regular Bridged Super Token");

        address superTokenFactoryAddr = vm.envAddress("SUPERTOKEN_FACTORY");

        _startBroadcast();

        BridgedSuperTokenProxy proxy = new BridgedSuperTokenProxy();
        proxy.initialize(ISuperTokenFactory(superTokenFactoryAddr), "SUP SuperToken", "SUPx", owner, initialSupply);
        proxy.transferOwnership(owner);
        console.log("$SUP BridgedSuperTokenProxy deployed at", address(proxy));
        console.log("--- SuperTokenFactory: %s", superTokenFactoryAddr);

        _stopBroadcast();
    }
}
