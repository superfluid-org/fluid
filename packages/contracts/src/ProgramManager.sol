pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluid, ISuperfluidPool, ISuperToken, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {IProgramManager} from "./interfaces/IProgramManager.sol";

using SuperTokenV1Library for ISuperToken;

contract ProgramManager is IProgramManager {
    /// FIXME storage packing

    /// @notice mapping storing the program details for a given program identifier
    mapping(uint8 programId => Program program) public programs;

    mapping(address signer => mapping(address user => uint256 lastValidNonce))
        private lastValidNonces;

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
    ) external returns (ISuperfluidPool distributionPool) {
        // Ensure program does not already exists
        if (address(programs[programId].distributionPool) != address(0))
            revert PROGRAM_ALREADY_CREATED();

        // Configure Superfluid GDA Pool
        PoolConfig memory poolConfig = PoolConfig({
            transferabilityForUnitsOwner: false,
            distributionFromAnyAddress: false
        });

        // Create Superfluid GDA Pool
        distributionPool = token.createPool(address(this), poolConfig);

        // Persist program details
        programs[programId] = Program(
            programAdmin,
            signer,
            token,
            distributionPool
        );

        /// FIXME emit ProgramCreated event
    }

    /**
     * @dev Update program signer
     * @param programId program identifier to be updated
     * @param newSigner new signer address
     */
    function updateProgramSigner(uint8 programId, address newSigner) external {
        // Ensure caller is program admin
        if (msg.sender != programs[programId].programAdmin)
            revert NOT_PROGRAM_ADMIN();

        // Update the program signer
        programs[programId].stackSigner = newSigner;

        /// FIXME emit ProgramSignerUpdated event
    }

    function updateUnits(
        uint8 programId,
        uint128 newUnits,
        uint256 nonce,
        bytes memory signature
    ) external {
        updateUserUnits(programId, msg.sender, newUnits, nonce, signature);
    }

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
    ) public {
        Program memory p = programs[programId];

        if (!_isNonceValid(p.stackSigner, user, nonce))
            revert INVALID_SIGNATURE("nonce");

        lastValidNonces[p.stackSigner][user] = nonce;

        if (!_verifySignature(p.stackSigner, user, newUnits, nonce, signature))
            revert INVALID_SIGNATURE("signer");

        p.token.updateMemberUnits(p.distributionPool, user, newUnits);

        /// FIXME emit UserUnitsUpdated event
    }

    function _isNonceValid(
        address signer,
        address user,
        uint256 nonce
    ) internal view returns (bool isValid) {
        isValid = nonce > lastValidNonces[signer][user];
    }

    function _verifySignature(
        address signer,
        address user,
        uint128 newUnits,
        uint256 nonce,
        bytes memory signature
    ) internal pure returns (bool isValid) {
        if (signature.length != 65)
            revert INVALID_SIGNATURE("signature length");

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(user, newUnits, nonce))
            )
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);

        isValid = ecrecover(ethSignedMessageHash, v, r, s) == signer;
    }

    function _splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
