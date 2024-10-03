pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluid, ISuperfluidPool, ISuperToken, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

using SuperTokenV1Library for ISuperToken;

contract ProgramManager {
    /// FIXME storage packing

    struct Program {
        address programAdmin;
        address stackSigner;
        ISuperToken token;
        ISuperfluidPool distributionPool;
    }

    mapping(uint8 programId => Program program) public programs;

    /// @notice Error thrown when attempting to create a program with an alredy existsing program identifier
    error PROGRAM_ALREADY_CREATED();

    /// @notice Error thrown when caller is not the program admin
    error NOT_PROGRAM_ADMIN();

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
    }

    function updateProgramSigner(uint8 programId, address signer) external {
        // Ensure caller is program admin
        if (msg.sender != programs[programId].programAdmin)
            revert NOT_PROGRAM_ADMIN();

        // Update the program signer
        programs[programId].stackSigner = signer;
    }
}
