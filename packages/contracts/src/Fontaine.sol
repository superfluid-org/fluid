// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperfluidPool,
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Contracts & Interfaces */
import { IFontaine } from "./interfaces/IFontaine.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title Fontaine Contract
 * @author Superfluid
 * @notice Contract responsible for flowing the token being unlocked from the locker to the locker owner
 *
 */
contract Fontaine is Initializable, IFontaine {
    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// FIXME storage packing

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable TAX_DISTRIBUTION_POOL;

    /// @notice Locker address associated to this Fontaine
    address public locker;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Fontaine contract constructor
     * @param fluid FLUID SuperToken interface
     * @param taxDistributionPool Tax Distribution Pool GDA contract address
     */
    constructor(ISuperToken fluid, ISuperfluidPool taxDistributionPool) {
        // Disable initializers to prevent implementation contract initalization
        _disableInitializers();

        // Sets immutable states
        FLUID = fluid;
        TAX_DISTRIBUTION_POOL = taxDistributionPool;
    }

    /**
     * @notice Fontaine contract initializer
     * @param connectedLocker Locker contract address connected to this Fontaine
     */
    function initialize(address connectedLocker, address lockerOwner, int96 unlockFlowRate, int96 taxFlowRate)
        external
        initializer
    {
        locker = connectedLocker;

        // Distribute Tax flow to Staker GDA Pool
        FLUID.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, taxFlowRate);

        // Create the unlocking flow from the Fontaine to the locker owner
        FLUID.createFlow(lockerOwner, unlockFlowRate);
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IFontaine
    function cancelUnlock(address lockerOwner) external onlyConnectedLocker {
        // Ensure that there is an unlocking process to cancel
        if (FLUID.getFlowRate(address(this), lockerOwner) == 0) {
            revert NO_ACTIVE_UNLOCK();
        }

        // Cancel the flow ongoing from this contract to the locker owner
        FLUID.deleteFlow(address(this), lockerOwner);

        // Cancel the flow ongoing from this contract to the Staker GDA Pool
        FLUID.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, 0);

        // Transfer entire FLUID balance back to the connected locker
        FLUID.transfer(msg.sender, FLUID.balanceOf(address(this)));
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
