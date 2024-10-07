pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */
import {Math} from "@openzeppelin-v5/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluidPool, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {ILockerDrainer} from "./interfaces/ILockerDrainer.sol";

using SuperTokenV1Library for ISuperToken;
// using Math for uint256;
using SafeCast for uint256;

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
        int96 drainFlowRate,
        int96 penaltyFlowRate
    ) external onlyConnectedLocker {
        // Distribute Penalty flow to Staker GDA Pool
        FLUID.distributeFlow(
            address(this),
            PENALTY_DRAINING_POOL,
            penaltyFlowRate
        );

        // Create Drain flow from the locker to the locker owner
        FLUID.createFlow(msg.sender, drainFlowRate);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyConnectedLocker() {
        if (msg.sender != locker) revert NOT_CONNECTED_LOCKER();
        _;
    }
}
