// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/* FLUID Contracts & Interfaces */
import { FluidLocker } from "./FluidLocker.sol";
import { Fontaine } from "./Fontaine.sol";
import { IFluidLockerFactory } from "./interfaces/IFluidLockerFactory.sol";
import { IPenaltyManager } from "./interfaces/IPenaltyManager.sol";

/**
 * @title Fluid Locker Factory Contract
 * @author Superfluid
 * @notice Deploys new Fluid Locker contracts and their associated Fontaine
 *
 */
contract FluidLockerFactory is IFluidLockerFactory {
    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice Locker Beacon contract address
    UpgradeableBeacon public immutable LOCKER_BEACON;

    /// @notice Fontaine Beacon contract address
    UpgradeableBeacon public immutable FONTAINE_BEACON;

    /// @notice Penalty Manager interface
    IPenaltyManager private immutable _PENALTY_MANAGER;

    /// @notice Stores wheather or not a locker has been created
    mapping(address locker => bool isCreated) internal _lockers;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice FLUID Locker Factory contract constructor
     * @param lockerImplementation Locker implementation contract address
     * @param fontaineImplementation Fontaine implementation contract address
     * @param penaltyManager Penalty Manager interface contract address
     */
    constructor(address lockerImplementation, address fontaineImplementation, IPenaltyManager penaltyManager) {
        // Sets the Penalty Manager interface
        _PENALTY_MANAGER = penaltyManager;

        // Deploy the Locker beacon with the Locker implementation contract
        LOCKER_BEACON = new UpgradeableBeacon(lockerImplementation);

        // Deploy the Fontaine beacon with the Fontaine implementation contract
        FONTAINE_BEACON = new UpgradeableBeacon(fontaineImplementation);

        // Transfer ownership of the Locker beacon to the deployer
        LOCKER_BEACON.transferOwnership(msg.sender);

        // Transfer ownership of the Fontaine beacon to the deployer
        FONTAINE_BEACON.transferOwnership(msg.sender);
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract() external returns (address lockerInstance) {
        lockerInstance = createLockerContract(msg.sender);
    }

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract(address lockerOwner) public returns (address lockerInstance) {
        // Use create2 to deploy a Locker Beacon Proxy with the hashed encoded LockerOwner as the salt
        lockerInstance =
            address(new BeaconProxy{ salt: keccak256(abi.encode(lockerOwner)) }(address(LOCKER_BEACON), ""));

        // Use create2 to deploy a Fontaine Beacon Proxy with the hashed encoded associated Locker address as the salt
        address fontaineInstance =
            address(new BeaconProxy{ salt: keccak256(abi.encode(lockerInstance)) }(address(FONTAINE_BEACON), ""));

        _lockers[lockerInstance] = true;

        // Initialize the new Fontaine instance
        Fontaine(fontaineInstance).initialize(lockerInstance);

        // Initialize the new Locker instance
        FluidLocker(lockerInstance).initialize(lockerOwner, fontaineInstance);

        // Approve the newly created locker to interact with the Penalty Manager
        _PENALTY_MANAGER.approveLocker(lockerInstance);

        /// FIXME emit Locker Created event
    }

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLockerFactory
    function isLockerCreated(address locker) external view returns (bool isCreated) {
        return _lockers[locker];
    }

    /// @inheritdoc IFluidLockerFactory
    function getLockerAddress(address user) external view returns (address lockerAddress) {
        lockerAddress = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            address(this),
                            keccak256(abi.encode(user)),
                            keccak256(
                                abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(LOCKER_BEACON), ""))
                            )
                        )
                    )
                )
            )
        );
    }

    /// @inheritdoc IFluidLockerFactory
    function getLockerBeaconImplementation() public view returns (address lockerBeaconImpl) {
        lockerBeaconImpl = LOCKER_BEACON.implementation();
    }

    /// @inheritdoc IFluidLockerFactory
    function getFontaineBeaconImplementation() public view returns (address fontaineBeaconImpl) {
        fontaineBeaconImpl = FONTAINE_BEACON.implementation();
    }
}
