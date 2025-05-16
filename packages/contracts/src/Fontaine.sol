// SPDX-License-Identifier: MIT

//                      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@                        @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@            @@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@            @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//                      @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

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
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface for staker distribution
    ISuperfluidPool public immutable STAKER_DISTRIBUTION_POOL;

    /// @notice Superfluid pool interface for provider distribution
    ISuperfluidPool public immutable PROVIDER_DISTRIBUTION_POOL;

    /// @notice Constant used to calculate the earliest date an unlock can be terminated
    uint256 public constant EARLY_END = 1 days;

    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice Stream recipient address
    address public recipient;

    /// @notice Flow rate between this Fontaine and the Staker Distribution Pool
    uint96 public stakerFlowRate;

    /// @notice Flow rate between this Fontaine and the unlock recipient
    uint96 public unlockFlowRate;

    /// @notice Date at which the unlock is completed
    uint128 public endDate;

    /// @notice Flow rate between this Fontaine and the Provider Distribution Pool
    uint96 public providerFlowRate;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Fontaine contract constructor
     * @param fluid FLUID SuperToken interface
     * @param stakerDistributionPool Tax Distribution Pool GDA contract address
     * @param providerDistributionPool Provider Distribution Pool GDA contract address
     */
    constructor(ISuperToken fluid, ISuperfluidPool stakerDistributionPool, ISuperfluidPool providerDistributionPool) {
        // Disable initializers to prevent implementation contract initalization
        _disableInitializers();

        // Sets immutable states
        FLUID = fluid;
        STAKER_DISTRIBUTION_POOL = stakerDistributionPool;
        PROVIDER_DISTRIBUTION_POOL = providerDistributionPool;
    }

    /// @inheritdoc IFontaine
    function initialize(
        address unlockRecipient,
        int96 targetUnlockFlowRate,
        int96 targetProviderFlowRate,
        int96 targetStakerFlowRate,
        uint128 unlockPeriod
    ) external initializer {
        // Ensure recipient is not a SuperApp
        if (ISuperfluid(FLUID.getHost()).isApp(ISuperApp(unlockRecipient))) revert CANNOT_UNLOCK_TO_SUPERAPP();

        // Sets the recipient address
        recipient = unlockRecipient;

        // Sets the early end date
        endDate = uint128(block.timestamp) + unlockPeriod;

        // Store the streams flow rates
        providerFlowRate = uint96(targetProviderFlowRate);
        stakerFlowRate = uint96(targetStakerFlowRate);
        unlockFlowRate = uint96(targetUnlockFlowRate);

        // Distribute Tax flow to Staker GDA Pool
        FLUID.distributeFlow(address(this), PROVIDER_DISTRIBUTION_POOL, targetProviderFlowRate);
        FLUID.distributeFlow(address(this), STAKER_DISTRIBUTION_POOL, targetStakerFlowRate);

        // Create the unlocking flow from the Fontaine to the locker owner
        FLUID.flow(unlockRecipient, targetUnlockFlowRate);
    }

    /// @inheritdoc IFontaine
    function terminateUnlock() external {
        // Validate early end date
        if (block.timestamp < endDate - EARLY_END) {
            revert TOO_EARLY_TO_TERMINATE_UNLOCK();
        }

        uint256 providerEarlyEndCompensation;
        uint256 stakerEarlyEndCompensation;

        if (block.timestamp < endDate) {
            // Calculate early end tax compensation
            providerEarlyEndCompensation = (endDate - block.timestamp) * providerFlowRate;
            stakerEarlyEndCompensation = (endDate - block.timestamp) * stakerFlowRate;
        }

        // Stops the streams by updating the flowrates to 0
        FLUID.distributeFlow(address(this), STAKER_DISTRIBUTION_POOL, 0);
        FLUID.distributeFlow(address(this), PROVIDER_DISTRIBUTION_POOL, 0);
        FLUID.flow(recipient, 0);

        // Transfer the remainders (tax + unlock)
        if (providerEarlyEndCompensation > 0) {
            FLUID.distribute(address(this), PROVIDER_DISTRIBUTION_POOL, providerEarlyEndCompensation);
        }
        if (stakerEarlyEndCompensation > 0) {
            FLUID.distribute(address(this), STAKER_DISTRIBUTION_POOL, stakerEarlyEndCompensation);
        }

        uint256 leftoverBalance = FLUID.balanceOf(address(this));
        if (leftoverBalance > 0) {
            FLUID.transfer(recipient, leftoverBalance);
        }
    }
}
