pragma solidity ^0.8.26;

interface ILockerDrainer {
    /// @notice Error thrown when the caller is not the connected locker
    error NOT_CONNECTED_LOCKER();

    function processDrain(int96 drainFlowRate, int96 penaltyFlowRate) external;
}
