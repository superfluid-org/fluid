pragma solidity ^0.8.26;

interface ILockerDrainer {
    /// @notice Error thrown when the caller is not the connected locker
    error NOT_CONNECTED_LOCKER();

    /// @notice Error thrown when attempting to process a drain while another drain is active
    error DRAIN_ALREADY_ACTIVE();

    /// @notice Error thrown when attempting to cancel a non-existant drain
    error NO_ACTIVE_DRAIN();

    function processDrain(
        address lockerOwner,
        int96 drainFlowRate,
        int96 penaltyFlowRate
    ) external;

    function cancelDrain(address lockerOwner) external;
}
