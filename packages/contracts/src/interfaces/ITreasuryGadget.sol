// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

/**
 * @title Treasury Gadget Interface
 * @author Superfluid
 * @notice Interface for the TreasuryGadget contract responsible for funding the community multisig
 */
interface ITreasuryGadget {
    //     ______           __                     ______
    //    / ____/_  _______/ /_____  ____ ___     / ____/_____________  __________
    //   / /   / / / / ___/ __/ __ \/ __ `__ \   / __/ / ___/ ___/ __ \/ ___/ ___/
    //  / /___/ /_/ (__  ) /_/ /_/ / / / / / /  / /___/ /  / /  / /_/ / /  (__  )
    //  \____/\__,_/____/\__/\____/_/ /_/ /_/  /_____/_/  /_/   \____/_/  /____/

    /// @notice Error thrown when an invalid parameter is provided
    error INVALID_PARAMETER();

    //      ______                 __
    //     / ____/   _____  ____  / /______
    //    / __/ | | / / _ \/ __ \/ __/ ___/
    //   / /___ | |/ /  __/ / / / /_(__  )
    //  /_____/ |___/\___/_/ /_/\__/____/

    /**
     * @notice Event emitted when community multisig is funded
     * @param totalAmount Total amount of FLUID tokens transferred
     * @param cliffAmount Amount of FLUID tokens transferred immediately
     * @param flowRate Flow rate for streaming remaining tokens
     */
    event CommunityMultisigFunded(uint256 totalAmount, uint256 cliffAmount, int96 flowRate);

    /**
     * @notice Event emitted when flow rate is updated
     * @param newFlowRate New flow rate set for the stream
     */
    event FlowUpdated(int96 newFlowRate);

    /**
     * @notice Event emitted when tokens are withdrawn
     * @param amount Amount of FLUID tokens withdrawn
     */
    event TokensWithdrawn(uint256 amount);

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Returns the $FLUID SuperToken interface
     */
    function FLUID() external view returns (ISuperToken);

    /**
     * @notice Returns the Community Multisig address
     */
    function COMMUNITY_MULTISIG() external view returns (address);

    /**
     * @notice Returns the Foundation Multisig address
     */
    function FOUNDATION_MULTISIG() external view returns (address);

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Funds the community multisig with FLUID tokens through a combination of cliff and stream
     * @dev Only the contract owner can perform this opeation
     * @param totalAmount Total amount of FLUID tokens to be transferred to this contract
     * @param cliffAmount Amount of FLUID tokens to be transferred immediately to community multisig
     * @param flowRate Flow rate at which remaining tokens will be streamed to community multisig
     */
    function fundCommunityMultisig(uint256 totalAmount, uint256 cliffAmount, int96 flowRate) external;

    /**
     * @notice Updates the flow rate of FLUID tokens being streamed to community multisig
     * @dev Only the contract owner can perform this opeation
     * @param newFlowRate New flow rate to set for the stream
     */
    function updateFunding(int96 newFlowRate) external;

    /**
     * @notice Withdraws FLUID tokens from this contract back to the owner
     * @dev Only the contract owner can perform this opeation
     * @param amount Amount of FLUID tokens to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Withdraws all FLUID tokens from this contract back to the owner
     * @dev Only the contract owner can perform this opeation
     */
    function withdrawAll() external;
}
