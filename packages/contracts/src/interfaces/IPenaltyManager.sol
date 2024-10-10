pragma solidity ^0.8.26;

interface IPenaltyManager {
    error NOT_APPROVED_LOCKER();
    error NOT_LOCKER_FACTORY();

    function updateStakerUnits(uint256 lockerStakedBalance) external;

    function updateLiquidityProvidersUnits(uint256 liquidityProvided) external;

    function setLockerFactory(address lockerFactoryAddress) external;

    function approveLocker(address lockerAddress) external;
}
