// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {FluidLocker} from "./FluidLocker.sol";
import {IFluidLockerFactory} from "./interfaces/IFluidLockerFactory.sol";
import {IPenaltyManager} from "./interfaces/IPenaltyManager.sol";

/**
 * @title Fluid Locker Factory Contract
 * @author Superfluid
 * @notice Deploys new Fluid Locker contracts
 **/
contract FluidLockerFactory is IFluidLockerFactory {
    UpgradeableBeacon public immutable LOCKER_BEACON;
    UpgradeableBeacon public immutable LOCKER_DRAINER_BEACON;

    IPenaltyManager private immutable _PENALTY_MANAGER;

    mapping(address locker => bool isCreated) internal _lockers;

    constructor(address implementation, IPenaltyManager penaltyManager) {
        // Sets the Penalty Manager interface
        _PENALTY_MANAGER = penaltyManager;

        // Deploy the beacon with the implementation contract
        LOCKER_BEACON = new UpgradeableBeacon(implementation);

        // Transfer ownership of the beacon to the deployer
        LOCKER_BEACON.transferOwnership(msg.sender);
    }

    /// @inheritdoc IFluidLockerFactory
    function isLockerCreated(
        address locker
    ) external view returns (bool isCreated) {
        return _lockers[locker];
    }

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract() external returns (address instance) {
        instance = createLockerContract(msg.sender);
    }

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract(
        address lockerOwner
    ) public returns (address instance) {
        // Use create2 to deploy a BeaconProxy with the hashed encoded LockerOwner as the salt
        instance = address(
            new BeaconProxy{salt: keccak256(abi.encode(lockerOwner))}(
                address(LOCKER_BEACON),
                ""
            )
        );

        _lockers[instance] = true;

        // Approve the newly created locker to interact with the Penalty Manager
        _PENALTY_MANAGER.approveLocker(instance);

        // Initialize the new Locker instance
        FluidLocker(instance).initialize(lockerOwner);

        /// FIXME emit Locker Created event
    }

    /// @inheritdoc IFluidLockerFactory
    function getLockerAddress(address user) external view returns (address) {
        return
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                keccak256(abi.encode(user)),
                                keccak256(
                                    abi.encodePacked(
                                        type(BeaconProxy).creationCode,
                                        abi.encode(address(LOCKER_BEACON), "")
                                    )
                                )
                            )
                        )
                    )
                )
            );
    }

    /// @inheritdoc IFluidLockerFactory
    function getBeaconImplementation() public view returns (address) {
        return LOCKER_BEACON.implementation();
    }
}
