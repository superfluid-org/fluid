pragma solidity ^0.8.23;

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperfluidPool,
    ISuperToken,
    PoolConfig
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Interfaces */
import { IEPProgramManager } from "./interfaces/IEPProgramManager.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title Ecosystem Partner Program Manager Contract
 * @author Superfluid
 * @notice Contract responsible for administrating the GDA pool that distribute FLUID to lockers
 *
 */
contract EPProgramManager is IEPProgramManager {
    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// FIXME storage packing check

    /// @notice Stores the program details for a given program identifier
    mapping(uint8 programId => EPProgram program) public programs;

    /// @notice Stores the last valid nonce used for a given signer and a given user
    mapping(address signer => mapping(address user => uint256 lastValidNonce)) private _lastValidNonces;

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IEPProgramManager
    function createProgram(uint8 programId, address programAdmin, address signer, ISuperToken token)
        external
        returns (ISuperfluidPool distributionPool)
    {
        // Ensure program does not already exists
        if (address(programs[programId].distributionPool) != address(0)) {
            revert PROGRAM_ALREADY_CREATED();
        }

        // Configure Superfluid GDA Pool
        PoolConfig memory poolConfig =
            PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: true });

        // Create Superfluid GDA Pool
        distributionPool = token.createPool(address(this), poolConfig);

        // Persist program details
        programs[programId] = EPProgram(programAdmin, signer, token, distributionPool);

        /// FIXME emit ProgramCreated event
    }

    /// @inheritdoc IEPProgramManager
    function updateProgramSigner(uint8 programId, address newSigner) external {
        // Ensure caller is program admin
        if (msg.sender != programs[programId].programAdmin) {
            revert NOT_PROGRAM_ADMIN();
        }

        // Update the program signer
        programs[programId].stackSigner = newSigner;

        /// FIXME emit ProgramSignerUpdated event
    }

    /// @inheritdoc IEPProgramManager
    function updateUnits(uint8 programId, uint128 newUnits, uint256 nonce, bytes memory stackSignature) external {
        updateUserUnits(programId, msg.sender, newUnits, nonce, stackSignature);
    }

    /// @inheritdoc IEPProgramManager
    function updateUnits(
        uint8[] memory programIds,
        uint128[] memory newUnits,
        uint256[] memory nonces,
        bytes[] memory stackSignatures
    ) external {
        uint256 length = programIds.length;

        if (length != newUnits.length || length != nonces.length || length != stackSignatures.length) {
            revert INVALID_PARAMETER();
        }

        for (uint256 i = 0; i < length; ++i) {
            updateUserUnits(programIds[i], msg.sender, newUnits[i], nonces[i], stackSignatures[i]);
        }
    }

    /// @inheritdoc IEPProgramManager
    function updateUserUnits(
        uint8 programId,
        address user,
        uint128 newUnits,
        uint256 nonce,
        bytes memory stackSignature
    ) public {
        EPProgram memory p = programs[programId];

        if (!_isNonceValid(p.stackSigner, user, nonce)) {
            revert INVALID_SIGNATURE("nonce");
        }

        _lastValidNonces[p.stackSigner][user] = nonce;

        if (!_verifySignature(p.stackSigner, user, newUnits, nonce, stackSignature)) revert INVALID_SIGNATURE("signer");

        p.token.updateMemberUnits(p.distributionPool, user, newUnits);

        /// FIXME emit UserUnitsUpdated event
    }

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IEPProgramManager
    function getProgramPool(uint8 programId) external view returns (ISuperfluidPool programPool) {
        programPool = programs[programId].distributionPool;
    }

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    function _isNonceValid(address signer, address user, uint256 nonce) internal view returns (bool isValid) {
        isValid = nonce > _lastValidNonces[signer][user];
    }

    function _verifySignature(address signer, address user, uint128 newUnits, uint256 nonce, bytes memory signature)
        internal
        pure
        returns (bool isValid)
    {
        if (signature.length != 65) {
            revert INVALID_SIGNATURE("signature length");
        }

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abi.encodePacked(user, newUnits, nonce)))
        );
        (bytes32 r, bytes32 s, uint8 v) = _splitSignature(signature);

        isValid = ecrecover(ethSignedMessageHash, v, r, s) == signer;
    }

    function _splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
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
