// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Fluid Locker Factory Contract Interface
 * @author Superfluid
 * @notice Deploys new Fluid Locker contracts and their associated Fontaine
 *
 */
interface IFluidLockerFactory {
    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Deploy a Locker and connected Fontaine for the caller
     * @return lockerInstance Deployed Locker contract address
     */
    function createLockerContract() external returns (address lockerInstance);

    /**
     * @notice Deploy a Locker and connected Fontaine for the given user
     * @param lockerOwner Owner address of the Locker to be deployed
     * @return lockerInstance Deployed Locker contract address
     */
    function createLockerContract(address lockerOwner) external returns (address lockerInstance);

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Returns wheather or not a locker has been deployed
     * @param locker Locker address to be queried
     * @return isCreated true if the locker is created, false otherwise
     */
    function isLockerCreated(address locker) external view returns (bool isCreated);

    /**
     * @notice Returns the locker contract address of the given user
     * @param user User address to be queried
     * @return lockerAddress The user's locker contract address
     */
    function getLockerAddress(address user) external view returns (address lockerAddress);

    /**
     * @notice Returns the locker beacon implementation contract address
     * @return lockerBeaconImpl The locker beacon implementation contract address
     */
    function getLockerBeaconImplementation() external view returns (address lockerBeaconImpl);

    /**
     * @notice Returns the fontaine beacon implementation contract address
     * @return fontaineBeaconImpl The fontaine beacon implementation contract address
     */
    function getFontaineBeaconImplementation() external view returns (address fontaineBeaconImpl);
}
