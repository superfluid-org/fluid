// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { Initializable } from "@openzeppelin-v5/contracts/proxy/utils/Initializable.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperfluid,
    ISuperfluidPool,
    ISuperToken,
    ISuperApp
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

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable TAX_DISTRIBUTION_POOL;

    /// @notice Constant used to calculate the earliest date an unlock can be terminated
    uint256 public constant EARLY_END = 1 days;

    /// @notice Stream recipient address
    address public recipient;

    /// @notice Flow rate between this Fontaine and the Tax Distribution Pool
    uint96 public taxFlowRate;

    /// @notice Flow rate between this Fontaine and the unlock recipient
    uint96 public unlockFlowRate;

    /// @notice Date at which the unlock is completed
    uint128 public endDate;

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

    /// @inheritdoc IFontaine
    function initialize(
        address unlockRecipient,
        int96 targetUnlockFlowRate,
        int96 targetTaxFlowRate,
        uint128 unlockPeriod
    ) external initializer {
        // Ensure recipient is not a SuperApp
        if (ISuperfluid(FLUID.getHost()).isApp(ISuperApp(unlockRecipient))) revert CANNOT_UNLOCK_TO_SUPERAPP();

        // Sets the recipient address
        recipient = unlockRecipient;

        // Sets the early end date
        endDate = uint128(block.timestamp) + unlockPeriod;

        // Store the streams flow rate
        taxFlowRate = uint96(targetTaxFlowRate);
        unlockFlowRate = uint96(targetUnlockFlowRate);

        // Distribute Tax flow to Staker GDA Pool
        FLUID.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, targetTaxFlowRate);

        // Create the unlocking flow from the Fontaine to the locker owner
        FLUID.flow(unlockRecipient, targetUnlockFlowRate);
    }

    function terminateUnlock() external {
        // Validate early end date
        if (block.timestamp < endDate - EARLY_END) {
            revert TOO_EARLY_TO_TERMINATE_UNLOCK();
        }

        uint256 taxEarlyEndCompensation;

        if (block.timestamp < endDate) {
            // Calculate early end tax compensation
            taxEarlyEndCompensation = (endDate - block.timestamp) * taxFlowRate;
        }

        // Stops the streams by updating the flowrates to 0
        FLUID.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, 0);
        FLUID.flow(recipient, 0);

        // Transfer the remainders (tax + unlock)
        if (taxEarlyEndCompensation > 0) {
            FLUID.distribute(address(this), TAX_DISTRIBUTION_POOL, taxEarlyEndCompensation);
        }

        uint256 leftoverBalance = FLUID.balanceOf(address(this));
        if (leftoverBalance > 0) {
            FLUID.transfer(recipient, leftoverBalance);
        }
    }
}
