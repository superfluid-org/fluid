// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/* FLUID Contracts & Interfaces */
import {FluidLocker} from "./FluidLocker.sol";
import {LockerDrainer} from "./LockerDrainer.sol";
import {IFluidLockerFactory} from "./interfaces/IFluidLockerFactory.sol";
import {IPenaltyManager} from "./interfaces/IPenaltyManager.sol";

/**
 * @title Fluid Locker Factory Contract
 * @author Superfluid
 * @notice Deploys new Fluid Locker contracts and their associated Locker Drainer
 **/
contract FluidLockerFactory is IFluidLockerFactory {
    UpgradeableBeacon public immutable LOCKER_BEACON;

    UpgradeableBeacon public immutable LOCKER_DRAINER_BEACON;

    IPenaltyManager private immutable _PENALTY_MANAGER;

    mapping(address locker => bool isCreated) internal _lockers;

    constructor(
        address lockerImplementation,
        address lockerDrainerImplementation,
        IPenaltyManager penaltyManager
    ) {
        // Sets the Penalty Manager interface
        _PENALTY_MANAGER = penaltyManager;

        // Deploy the Locker beacon with the Locker implementation contract
        LOCKER_BEACON = new UpgradeableBeacon(lockerImplementation);

        // Deploy the Locker Drainer beacon with the Locker Drainer implementation contract
        LOCKER_DRAINER_BEACON = new UpgradeableBeacon(
            lockerDrainerImplementation
        );

        // Transfer ownership of the Locker beacon to the deployer
        LOCKER_BEACON.transferOwnership(msg.sender);

        // Transfer ownership of the Locker Drainer beacon to the deployer
        LOCKER_DRAINER_BEACON.transferOwnership(msg.sender);
    }

    /// @inheritdoc IFluidLockerFactory
    function isLockerCreated(
        address locker
    ) external view returns (bool isCreated) {
        return _lockers[locker];
    }

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract() external returns (address lockerInstance) {
        lockerInstance = createLockerContract(msg.sender);
    }

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract(
        address lockerOwner
    ) public returns (address lockerInstance) {
        // Use create2 to deploy a Locker BeaconProxy with the hashed encoded LockerOwner as the salt
        lockerInstance = address(
            new BeaconProxy{salt: keccak256(abi.encode(lockerOwner))}(
                address(LOCKER_BEACON),
                ""
            )
        );

        // Use create2 to deploy a Locker Drainer BeaconProxy with the hashed encoded associated Locker address as the salt
        address lockerDrainerInstance = address(
            new BeaconProxy{salt: keccak256(abi.encode(lockerInstance))}(
                address(LOCKER_DRAINER_BEACON),
                ""
            )
        );

        _lockers[lockerInstance] = true;

        // Initialize the new Locker Drainer instance
        LockerDrainer(lockerDrainerInstance).initialize(lockerInstance);

        // Initialize the new Locker instance
        FluidLocker(lockerInstance).initialize(
            lockerOwner,
            lockerDrainerInstance
        );

        // Approve the newly created locker to interact with the Penalty Manager
        _PENALTY_MANAGER.approveLocker(lockerInstance);

        /// FIXME emit Locker Created event
    }

    /// @inheritdoc IFluidLockerFactory
    function getLockerAddress(
        address user
    ) external view returns (address lockerAddress) {
        lockerAddress = address(
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
    function getLockerBeaconImplementation()
        public
        view
        returns (address lockerBeaconImpl)
    {
        lockerBeaconImpl = LOCKER_BEACON.implementation();
    }

    /// @inheritdoc IFluidLockerFactory
    function getLockerDrainerBeaconImplementation()
        public
        view
        returns (address lockerDrainerBeaconImpl)
    {
        lockerDrainerBeaconImpl = LOCKER_DRAINER_BEACON.implementation();
    }
}
