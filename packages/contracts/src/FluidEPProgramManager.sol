// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Openzeppelin Contracts & Interfaces */
import { Ownable } from "@openzeppelin-v5/contracts/access/Ownable.sol";
import { SafeCast } from "@openzeppelin-v5/contracts/utils/math/SafeCast.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {
    ISuperToken,
    ISuperfluidPool,
    PoolConfig
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* FLUID Contracts & Interfaces */
import { EPProgramManager, IEPProgramManager } from "./EPProgramManager.sol";
import { IFluidLockerFactory } from "./interfaces/IFluidLockerFactory.sol";
import { IStakingRewardController } from "./interfaces/IStakingRewardController.sol";

using SuperTokenV1Library for ISuperToken;
using SafeCast for int256;

/**
 * @title Superfluid Ecosystem Partner Program Manager Contract
 * @author Superfluid
 * @notice Contract responsible for administrating the GDA pool that distribute FLUID to lockers
 *
 */
contract FluidEPProgramManager is Ownable, EPProgramManager {
    //     ______           __                     ______
    //    / ____/_  _______/ /_____  ____ ___     / ____/_____________  __________
    //   / /   / / / / ___/ __/ __ \/ __ `__ \   / __/ / ___/ ___/ __ \/ ___/ ___/
    //  / /___/ /_/ (__  ) /_/ /_/ / / / / / /  / /___/ /  / /  / /_/ / /  (__  )
    //  \____/\__,_/____/\__/\____/_/ /_/ /_/  /_____/_/  /_/   \____/_/  /____/

    /// @notice Error thrown when attempting to add units to a non-existant locker
    /// @dev Error Selector :
    error LOCKER_NOT_FOUND();

    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice Staking Reward Controller contract interface
    IStakingRewardController public immutable STAKING_REWARD_CONTROLLER;

    /// @notice Program Duration used to calculate flow rates
    uint256 public constant PROGRAM_DURATION = 90 days;

    /// @notice Basis points denominator (for percentage calculation)
    uint96 private constant _BP_DENOMINATOR = 10_000;

    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice Staking subsidy funding rate
    uint96 public subsidyFundingRate;

    /// @notice Fluid Locker Factory interface
    IFluidLockerFactory public fluidLockerFactory;

    /// @notice Fluid treasury account address
    address public fluidTreasury;

    /// @notice Stores the subsidyFlowRate for a given program
    mapping(uint256 programId => int96 subsidyFlowRate) private _subsidyFlowRatePerProgram;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Superfluid Ecosystem Partner Program Manager constructor
     * @param owner contract owner address
     */
    constructor(address owner, address treasury, IStakingRewardController stakingRewardController) Ownable(owner) {
        fluidTreasury = treasury;
        STAKING_REWARD_CONTROLLER = stakingRewardController;
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc IEPProgramManager
    /// @dev Only the contract owner can perform this operation
    function createProgram(uint256 programId, address programAdmin, address signer, ISuperToken token)
        external
        override
        onlyOwner
        returns (ISuperfluidPool distributionPool)
    {
        // Input validation
        if (programId == 0) revert INVALID_PARAMETER();
        if (programAdmin == address(0)) revert INVALID_PARAMETER();
        if (signer == address(0)) revert INVALID_PARAMETER();
        if (address(token) == address(0)) revert INVALID_PARAMETER();
        if (address(programs[programId].distributionPool) != address(0)) {
            revert PROGRAM_ALREADY_CREATED();
        }

        // Configure Superfluid GDA Pool
        /// FIXME : We could change the `distributeFromAnyAddress` to false here
        ///        (if we agree that only this contract will distribute to the program pool)
        PoolConfig memory poolConfig =
            PoolConfig({ transferabilityForUnitsOwner: false, distributionFromAnyAddress: true });

        // Create Superfluid GDA Pool
        distributionPool = token.createPool(address(this), poolConfig);

        // Persist program details
        programs[programId] = EPProgram({
            programAdmin: programAdmin,
            stackSigner: signer,
            token: token,
            distributionPool: distributionPool
        });

        emit IEPProgramManager.ProgramCreated(
            programId, programAdmin, signer, address(token), address(distributionPool)
        );
    }

    /**
     * @notice Programatically calculate and initiate distribution to the GDA pools and staking reserve
     * @dev Only the contract owner can perform this operation
     * @param programId program identifier to start funding
     * @param totalAmount total amount to be distributed (including staking subsidy)
     */
    function startFunding(uint256 programId, uint256 totalAmount) external onlyOwner {
        EPProgram memory program = programs[programId];

        // Fetch funds from FLUID Treasury (requires prior approval from the Treasury)
        program.token.transferFrom(fluidTreasury, address(this), totalAmount);

        int96 totalFlowRate = int256(totalAmount / PROGRAM_DURATION).toInt96();
        int96 subsidyFlowRate = (totalFlowRate * int96(subsidyFundingRate)) / int96(_BP_DENOMINATOR);
        int96 fundingFlowRate = totalFlowRate - subsidyFlowRate;

        _subsidyFlowRatePerProgram[programId] = subsidyFlowRate;

        // Distribute flow to Program GDA pool
        program.token.distributeFlow(address(this), program.distributionPool, fundingFlowRate);

        if (subsidyFlowRate > 0) {
            // Create or update the subsidy flow to the Staking Reward Controller
            int96 newSubsidyFlow = _createOrUpdateSubsidyFlow(program.token, subsidyFlowRate);

            // Refresh the subsidy distribution flow
            STAKING_REWARD_CONTROLLER.refreshSubsidyDistribution(newSubsidyFlow);
        }
    }

    /**
     * @notice Stop flows from this contract to the distribution pool and to the staking reserve
     * @dev Only the contract owner can perform this operation
     * @param programId program identifier to stop funding
     */
    function stopFunding(uint256 programId) external onlyOwner {
        EPProgram memory program = programs[programId];

        // Stop the distribution flow to Program GDA pool
        program.token.distributeFlow(address(this), program.distributionPool, 0);

        int96 programSubsidyFlowRate = _subsidyFlowRatePerProgram[programId];

        if (programSubsidyFlowRate > 0) {
            // Delete or update the subsidy flow to the Staking Reward Controller
            int96 newSubsidyFlow = _deleteOrUpdateSubsidyFlow(program.token, programSubsidyFlowRate);

            // Refresh the subsidy distribution flow
            STAKING_REWARD_CONTROLLER.refreshSubsidyDistribution(newSubsidyFlow);
        }
    }

    /**
     * @notice Update the Locker Factory contract address
     * @dev Only the contract owner can perform this operation
     * @param lockerFactoryAddress Locker Factory contract address to be set
     */
    function setLockerFactory(address lockerFactoryAddress) external onlyOwner {
        // Input validation
        if (lockerFactoryAddress == address(0)) revert INVALID_PARAMETER();
        fluidLockerFactory = IFluidLockerFactory(lockerFactoryAddress);
    }

    /**
     * @notice Update the Treasury address
     * @dev Only the contract owner can perform this operation
     * @param treasuryAddress Treasury address to be set
     */
    function setTreasury(address treasuryAddress) external onlyOwner {
        // Input validation
        if (treasuryAddress == address(0)) revert INVALID_PARAMETER();
        fluidTreasury = treasuryAddress;
    }

    /**
     * @notice Update the Staking Subsidy Rate
     * @dev Only the contract owner can perform this operation
     * @param subsidyRate Subsidy rate to be set (expressed in basis points)
     */
    function setSubsidyRate(uint96 subsidyRate) external onlyOwner {
        // Input validation
        if (subsidyFundingRate > _BP_DENOMINATOR) revert INVALID_PARAMETER();
        subsidyFundingRate = subsidyRate;
    }

    /**
     * @notice Withdraw all funds from this contract to the treasury
     * @dev Only the contract owner can perform this operation
     * @param token token contract address
     */
    function emergencyWithdraw(ISuperToken token) external onlyOwner {
        token.transfer(fluidTreasury, token.balanceOf(address(this)));
    }

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Update GDA Pool units of the locker associated to the given user
     * @param program The program associated with the update
     * @param stackPoints Amount of stack points
     * @param user The user address to receive the units
     */
    function _poolUpdate(EPProgram memory program, uint256 stackPoints, address user) internal override {
        // Get the locker address belonging to the given user
        address locker = fluidLockerFactory.getLockerAddress(user);

        // Ensure the locker exists
        if (locker == address(0)) revert LOCKER_NOT_FOUND();

        // Update the locker's units in the program GDA pool
        program.distributionPool.updateMemberUnits(locker, uint128(stackPoints));
    }

    /**
     * @notice Create or update the subsidy flow from this contract to the staking subsidy reserve
     * @param token token contract address
     * @param subsidyFlowRateToIncrease flow rate to add to the current global subsidy flow rate
     * @return newSubsidyFlowRate the new current global subsidy flow rate
     */
    function _createOrUpdateSubsidyFlow(ISuperToken token, int96 subsidyFlowRateToIncrease)
        internal
        returns (int96 newSubsidyFlowRate)
    {
        // Fetch current flow between this contract and the Staking Reward Controller
        int96 currentSubsidyFlowRate = token.getFlowRate(address(this), address(STAKING_REWARD_CONTROLLER));

        // Calculate the new subsidy flow rate
        newSubsidyFlowRate = currentSubsidyFlowRate + subsidyFlowRateToIncrease;

        // Create the flow if it does not exists, increase it otherwise
        if (currentSubsidyFlowRate == 0) {
            token.createFlow(address(STAKING_REWARD_CONTROLLER), newSubsidyFlowRate);
        } else {
            token.updateFlow(address(STAKING_REWARD_CONTROLLER), newSubsidyFlowRate);
        }
    }

    /**
     * @notice Delete or update the subsidy flow from this contract to the staking subsidy reserve
     * @param token token contract address
     * @param subsidyFlowRateToDecrease flow rate to deduce from the current global subsidy flow rate
     * @return newSubsidyFlowRate the new current global subsidy flow rate
     */
    function _deleteOrUpdateSubsidyFlow(ISuperToken token, int96 subsidyFlowRateToDecrease)
        internal
        returns (int96 newSubsidyFlowRate)
    {
        // Fetch current flow between this contract and the Staking Reward Controller
        int96 currentSubsidyFlowRate = token.getFlowRate(address(this), address(STAKING_REWARD_CONTROLLER));

        // Delete the flow if it is only composed of the current subsidy flow to remove, decrease it otherwise
        if (currentSubsidyFlowRate <= subsidyFlowRateToDecrease) {
            newSubsidyFlowRate = 0;
            token.deleteFlow(address(this), address(STAKING_REWARD_CONTROLLER));
        } else {
            newSubsidyFlowRate = currentSubsidyFlowRate - subsidyFlowRateToDecrease;
            token.updateFlow(address(STAKING_REWARD_CONTROLLER), newSubsidyFlowRate);
        }
    }
}
