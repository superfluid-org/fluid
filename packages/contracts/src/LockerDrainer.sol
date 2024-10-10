pragma solidity ^0.8.26;

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluidPool, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ILockerDrainer} from "./interfaces/ILockerDrainer.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title Locker Drainer Contract
 * @author Superfluid
 * @notice Contract responsible for flowing drained token from the locker to the locker owner
 **/
contract LockerDrainer is ILockerDrainer {
    /// FIXME storage packing

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable PENALTY_DRAINING_POOL;

    /// @notice Locker address associated to this Drainer
    address public locker;

    constructor(ISuperToken fluid, ISuperfluidPool penaltyDrainingPool) {
        FLUID = fluid;
        PENALTY_DRAINING_POOL = penaltyDrainingPool;
    }

    function initialize(address connectedLocker) external {
        locker = connectedLocker;
    }

    function processDrain(
        address lockerOwner,
        int96 drainFlowRate,
        int96 penaltyFlowRate
    ) external onlyConnectedLocker {
        // Ensure that there is no active drain
        if (FLUID.getFlowRate(address(this), lockerOwner) != 0)
            revert DRAIN_ALREADY_ACTIVE();

        // Distribute Penalty flow to Staker GDA Pool
        FLUID.distributeFlow(
            address(this),
            PENALTY_DRAINING_POOL,
            penaltyFlowRate
        );

        // Create Drain flow from the locker drainer to the locker owner
        FLUID.createFlow(lockerOwner, drainFlowRate);
    }

    function cancelDrain(address lockerOwner) external onlyConnectedLocker {
        // Ensure that there is a drain to cancel
        if (FLUID.getFlowRate(address(this), lockerOwner) == 0)
            revert NO_ACTIVE_DRAIN();

        // Transfer entire FLUID balance back to the connected locker
        FLUID.transfer(msg.sender, FLUID.balanceOf(address(this)));
        FLUID.deleteFlow(address(this), lockerOwner);

        /// FIXME Is there any way to delete the distributionFlow to the PENALTY_DRAINING_POOL ?
    }

    /**
     * @dev Reverts if called by any account other than the connected locker.
     */
    modifier onlyConnectedLocker() {
        if (msg.sender != locker) revert NOT_CONNECTED_LOCKER();
        _;
    }
}
