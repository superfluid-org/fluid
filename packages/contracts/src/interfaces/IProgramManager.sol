pragma solidity ^0.8.26;

import {ISuperfluidPool, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

/**
 * @title Program Manager Contract Interface
 * @author Superfluid
 * @notice Contract responsible for administrating the GDA pool that distribute FLUID to lockers
 **/
interface IProgramManager {
    /**
     * @notice Program Data Type
     * @param programAdmin program admin address
     * @param stackSigner signer address
     * @param token SuperToken to be distributed
     * @return distributionPool deployed Superfluid Pool contract address
     */
    struct Program {
        address programAdmin;
        address stackSigner;
        ISuperToken token;
        ISuperfluidPool distributionPool;
    }

    /// @notice Error thrown when attempting to create a program with an alredy existsing program identifier
    error PROGRAM_ALREADY_CREATED();

    /// @notice Error thrown when caller is not the program admin
    error NOT_PROGRAM_ADMIN();

    /// @notice Error thrown when caller is not the program admin
    error INVALID_PARAMETER();

    /// @notice Error thrown when a signature is of invalid
    error INVALID_SIGNATURE(string reason);

    /**
     * @notice Creates a new distribution program
     * @param programId program identifier to be created
     * @param programAdmin program admin address
     * @param signer signer address
     * @param token SuperToken to be distributed
     * @return distributionPool deployed Superfluid Pool contract address
     */
    function createProgram(
        uint8 programId,
        address programAdmin,
        address signer,
        ISuperToken token
    ) external returns (ISuperfluidPool distributionPool);

    /**
     * @notice Update program signer
     * @dev Only the program admin can perform this operation
     * @param programId program identifier to be updated
     * @param newSigner new signer address
     */
    function updateProgramSigner(uint8 programId, address newSigner) external;

    /**
     * @notice Update units within the distribution pool associated to the given program
     * @param programId program identifier associated to the distribution pool
     * @param newUnits unit amount to be granted
     * @param nonce nonce corresponding to the stack signature
     * @param stackSignature stack signature containing necessary info to update units
     */
    function updateUnits(
        uint8 programId,
        uint128 newUnits,
        uint256 nonce,
        bytes memory stackSignature
    ) external;

    /**
     * @notice Batch update units within the distribution pools associated to the given programs
     * @param programIds array of program identifiers associated to the distribution pool
     * @param newUnits array of unit amounts to be granted
     * @param nonces array nonces corresponding to the stack signatures
     * @param stackSignatures array of stack signatures containing necessary info to update units
     */
    function updateUnits(
        uint8[] memory programIds,
        uint128[] memory newUnits,
        uint256[] memory nonces,
        bytes[] memory stackSignatures
    ) external;

    /**
     * @notice Update units within the distribution pool associated to the given program
     * @param programId program identifier associated to the distribution pool
     * @param user address to grants the units to
     * @param newUnits unit amount to be granted
     * @param nonce nonce corresponding to the stack signature
     * @param stackSignature stack signature containing necessary info to update units
     */
    function updateUserUnits(
        uint8 programId,
        address user,
        uint128 newUnits,
        uint256 nonce,
        bytes memory stackSignature
    ) external;
}
