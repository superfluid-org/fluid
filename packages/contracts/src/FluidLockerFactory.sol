// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { ERC1967Utils } from "@openzeppelin-v5/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";

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
contract FluidLockerFactory is Initializable, IFluidLockerFactory {
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice Locker Beacon contract address
    UpgradeableBeacon public immutable LOCKER_BEACON;

    /// @notice Penalty Manager interface
    IPenaltyManager private immutable _PENALTY_MANAGER;

    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice Pause Status of this contract
    bool public isPaused;

    /// @notice Governance Multisig address
    address public governor;

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
     * @param penaltyManager Penalty Manager interface contract address
     */
    constructor(address lockerImplementation, IPenaltyManager penaltyManager) {
        // Sets the Penalty Manager interface
        _PENALTY_MANAGER = penaltyManager;

        // Deploy the Locker beacon with the Locker implementation contract
        LOCKER_BEACON = new UpgradeableBeacon(lockerImplementation);

        // Transfer ownership of the Locker beacon to the deployer
        LOCKER_BEACON.transferOwnership(msg.sender);

        _disableInitializers();
    }

    /**
     * @notice FLUID Locker Factory contract initializer
     * @param _governor the governor address
     */
    function initialize(address _governor) external initializer {
        // Sets the governor address
        governor = _governor;
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLockerFactory
    function createLockerContract() external returns (address lockerInstance) {
        if (isPaused) revert LOCKER_CREATION_PAUSED();
        lockerInstance = _createLockerContract(msg.sender);
    }

    /// @inheritdoc IFluidLockerFactory
    function upgradeTo(address newImplementation) external onlyGovernor {
        ERC1967Utils.upgradeToAndCall(newImplementation, new bytes(0));
    }

    /// @inheritdoc IFluidLockerFactory
    function setGovernor(address newGovernor) external onlyGovernor {
        governor = newGovernor;
    }

    /// @inheritdoc IFluidLockerFactory
    function pauseLockerCreation() external onlyGovernor {
        isPaused = true;
    }

    /// @inheritdoc IFluidLockerFactory
    function unpauseLockerCreation() external onlyGovernor {
        isPaused = false;
    }

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFluidLockerFactory
    function getUserLocker(address user) external view returns (bool isCreated, address lockerAddress) {
        lockerAddress = getLockerAddress(user);
        isCreated = isLockerCreated(lockerAddress);
    }

    /// @inheritdoc IFluidLockerFactory
    function isLockerCreated(address locker) public view returns (bool isCreated) {
        return _lockers[locker];
    }

    /// @inheritdoc IFluidLockerFactory
    function getLockerAddress(address user) public view returns (address lockerAddress) {
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

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    function _createLockerContract(address lockerOwner) internal returns (address lockerInstance) {
        // Use create2 to deploy a Locker Beacon Proxy with the hashed encoded LockerOwner as the salt
        lockerInstance =
            address(new BeaconProxy{ salt: keccak256(abi.encode(lockerOwner)) }(address(LOCKER_BEACON), ""));

        _lockers[lockerInstance] = true;

        // Initialize the new Locker instance
        FluidLocker(lockerInstance).initialize(lockerOwner);

        // Approve the newly created locker to interact with the Penalty Manager
        _PENALTY_MANAGER.approveLocker(lockerInstance);

        /// FIXME emit Locker Created event
    }

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @dev Throws if called by any account other than the Locker Factory contract
     */
    modifier onlyGovernor() {
        if (msg.sender != governor) revert NOT_GOVERNOR();
        _;
    }
}
