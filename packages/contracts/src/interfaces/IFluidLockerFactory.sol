// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Fluid Locker Factory Contract Interface
 * @author Superfluid
 * @notice Deploys new Fluid Locker contracts
 **/
interface IFluidLockerFactory {
    function isLockerCreated(
        address locker
    ) external view returns (bool isCreated);

    function createLockerContract() external returns (address instance);

    function createLockerContract(
        address lockerOwner
    ) external returns (address instance);

    function getLockerAddress(address user) external view returns (address);

    function getBeaconImplementation() external view returns (address);
}
