pragma solidity ^0.8.26;

import {ISuperfluidPool, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface IProgramManager {
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

    /// @notice Error thrown when a signature is of invalid
    error INVALID_SIGNATURE(string reason);

    /**
     * @dev Creates a new distribution program
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
     * @dev Update program signer
     * @param programId program identifier to be updated
     * @param newSigner new signer address
     */
    function updateProgramSigner(uint8 programId, address newSigner) external;

    function updateUnits(
        uint8 programId,
        uint128 newUnits,
        uint256 nonce,
        bytes memory signature
    ) external;

    // FIXME : add Nonce Vs Signer Vs User check
    /** CASE : if nonce check is not added a signature can be reused later after a program wipe (i.e. resetting all units)
     *         ideally, once a program end, the GDA pool is reused for a new campaign, so all users must be disconnected
     *         and the signer updated. Altho, if the signer is not updated and the nonce check not enforced, user could reused
     *         previous signature to get themself units they dont deserve.
     */
    function updateUserUnits(
        uint8 programId,
        address user,
        uint128 newUnits,
        uint256 nonce,
        bytes memory signature
    ) external;
}
