// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title Fontaine Contract Interface
 * @author Superfluid
 * @notice Contract responsible for flowing drained token from the locker to the locker owner
 *
 */
interface IFontaine {
    //     ______           __                     ______
    //    / ____/_  _______/ /_____  ____ ___     / ____/_____________  __________
    //   / /   / / / / ___/ __/ __ \/ __ `__ \   / __/ / ___/ ___/ __ \/ ___/ ___/
    //  / /___/ /_/ (__  ) /_/ /_/ / / / / / /  / /___/ /  / /  / /_/ / /  (__  )
    //  \____/\__,_/____/\__/\____/_/ /_/ /_/  /_____/_/  /_/   \____/_/  /____/

    /// @notice Error thrown when the caller is not the connected locker
    error NOT_CONNECTED_LOCKER();

    /// @notice Error thrown when attempting to process a drain while another drain is active
    error DRAIN_ALREADY_ACTIVE();

    /// @notice Error thrown when attempting to cancel a non-existant drain
    error NO_ACTIVE_DRAIN();

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Creates a flow to the locker owner and distribute a flow to the penalty GDA pool
     * @param lockerOwner locker owner account address
     * @param drainFlowRate FLUID flow rate from this contract to the locker owner
     * @param penaltyFlowRate FLUID flow rate from this contract to the penalty GDA pool
     */
    function processDrain(address lockerOwner, int96 drainFlowRate, int96 penaltyFlowRate) external;

    /**
     * @notice Stops the flow to the locker owner and transfer residual FLUID back to the connected locker
     * @param lockerOwner locker owner account address
     */
    function cancelDrain(address lockerOwner) external;
}
