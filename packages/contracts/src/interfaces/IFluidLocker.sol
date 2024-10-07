pragma solidity ^0.8.26;

interface IFluidLocker {
    /// @notice Error thrown when the caller is not the owner
    error NOT_LOCKER_OWNER();

    /// @notice Error thrown when attempting to perform a forbidden operation
    error FORBIDDEN();

    /// @notice Error thrown when attempting to drain this locker with an invalid drain period
    error INVALID_DRAIN_PERIOD();

    /// @notice Error thrown when attempting to drain a locker that does not have available $FLUID
    error NO_FLUID_TO_DRAIN();

    function claim(
        uint8 programId,
        uint128 totalProgramUnits,
        uint256 nonce,
        bytes memory stackSignature
    ) external;

    function claim(
        uint8[] memory programIds,
        uint128[] memory totalProgramUnits,
        uint256[] memory nonces,
        bytes[] memory stackSignatures
    ) external;

    function lock(uint256 amount) external;

    function drain(uint128 drainPeriod) external;

    function stake() external;

    function unstake() external;

    function transferLocker(address recipient) external;
}
