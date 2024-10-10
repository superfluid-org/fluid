pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */
import {Initializable} from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluidPool, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Contracts & Interfaces */
import {ILockerDrainer} from "./interfaces/ILockerDrainer.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title Locker Drainer Contract
 * @author Superfluid
 * @notice Contract responsible for flowing drained token from the locker to the locker owner
 **/
contract LockerDrainer is Initializable, ILockerDrainer {
    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// FIXME storage packing

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable PENALTY_DRAINING_POOL;

    /// @notice Locker address associated to this Drainer
    address public locker;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Locker Drainer contract constructor
     * @param fluid FLUID SuperToken interface
     * @param penaltyDrainingPool Penalty Draining Pool GDA contract address
     */
    constructor(ISuperToken fluid, ISuperfluidPool penaltyDrainingPool) {
        // Disable initializers to prevent implementation contract initalization
        _disableInitializers();

        // Sets immutable states
        FLUID = fluid;
        PENALTY_DRAINING_POOL = penaltyDrainingPool;
    }

    /**
     * @notice Locker Drainer contract initializer
     * @param connectedLocker Locker contract address connected to this Locker Drainer
     */
    function initialize(address connectedLocker) external initializer {
        locker = connectedLocker;
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc ILockerDrainer
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

    /// @inheritdoc ILockerDrainer
    function cancelDrain(address lockerOwner) external onlyConnectedLocker {
        // Ensure that there is a drain to cancel
        if (FLUID.getFlowRate(address(this), lockerOwner) == 0)
            revert NO_ACTIVE_DRAIN();

        // Transfer entire FLUID balance back to the connected locker
        FLUID.transfer(msg.sender, FLUID.balanceOf(address(this)));
        FLUID.deleteFlow(address(this), lockerOwner);

        /// FIXME Is there any way to delete the distributionFlow to the PENALTY_DRAINING_POOL ?
    }

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @dev Reverts if called by any account other than the connected locker.
     */
    modifier onlyConnectedLocker() {
        if (msg.sender != locker) revert NOT_CONNECTED_LOCKER();
        _;
    }
}
