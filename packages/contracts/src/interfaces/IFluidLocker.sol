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

    /// @notice Error thrown when attempting to unstake from locker that does not have staked $FLUID
    error NO_FLUID_TO_UNSTAKE();

    /// @notice Error thrown when attempting to stake from locker that does not have available $FLUID
    error NO_FLUID_TO_STAKE();

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Update this locker units within the given program identifier's GDA pool
     * @param programId program identifier corresponding to the unit update
     * @param totalProgramUnits new total amount of units
     * @param nonce nonce associated to the signature provided by Stack
     * @param stackSignature stack signature containing necessary info to update units
     */
    function claim(
        uint8 programId,
        uint128 totalProgramUnits,
        uint256 nonce,
        bytes memory stackSignature
    ) external;

    /**
     * @notice Batch update this locker units within the given programs identifier's GDA pools
     * @param programIds array of program identifiers corresponding to the unit update
     * @param totalProgramUnits array new total amount of units
     * @param nonces array of nonce associated to the signatures provided by Stack
     * @param stackSignatures array of stack signatures containing necessary info to update units
     */
    function claim(
        uint8[] memory programIds,
        uint128[] memory totalProgramUnits,
        uint256[] memory nonces,
        bytes[] memory stackSignatures
    ) external;

    /**
     * @notice Lock a given `amount` of FLUID Token in this Locker
     * @dev Requires preliminary token approval
     * @param amount amount of FLUID Token to lock
     */
    function lock(uint256 amount) external;
    /**
     * @notice Drain the available FLUID Token from this locker
     * @dev Only this Locker owner can call this function
     * @param drainPeriod the desired draining period (instant drain if sets to 0)
     */
    function drain(uint128 drainPeriod) external;

    /**
     * @notice Stake all the available FLUID Token of this locker
     * @dev Only this Locker owner can call this function
     */
    function stake() external;

    /**
     * @notice Unstake all the staked FLUID Token of this locker
     * @dev Only this Locker owner can call this function
     */
    function unstake() external;

    /**
     * @notice Transfer this Locker to the given `recipient`
     * @dev Only this Locker owner can call this function
     * @param recipient address to transfer this Locker to
     */
    function transferLocker(address recipient) external;

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Returns this Lockers' staked FLUID Token balance
     * @return sBalance amount of FLUID Token staked in this Locker
     */
    function getStakedBalance() external view returns (uint256 sBalance);

    /**
     * @notice Returns this Lockers' available FLUID Token balance
     * @dev Available balance is the total balance minus the staked balance
     * @return aBalance amount of FLUID Token available in this Locker
     */
    function getAvailableBalance() external view returns (uint256 aBalance);
}
