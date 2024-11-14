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
    //      ____        __        __
    //     / __ \____ _/ /_____ _/ /___  ______  ___  _____
    //    / / / / __ `/ __/ __ `/ __/ / / / __ \/ _ \/ ___/
    //   / /_/ / /_/ / /_/ /_/ / /_/ /_/ / /_/ /  __(__  )
    //  /_____/\__,_/\__/\__,_/\__/\__, / .___/\___/____/
    //                            /____/_/

    /**
     * @notice Fluid Program related details Data Type
     * @param fundingFlowRate flow rate between this contract and the program pool
     * @param subsidyFlowRate flow rate between the Staking Reward Controller contract and the tax distribution pool
     * @param fundingStartDate timestamp at which the program is funded
     * @param fundingRemainder program residual amount
     * @param subsidyRemainder subsidy residual amount
     */
    struct FluidProgramDetails {
        int96 fundingFlowRate;
        int96 subsidyFlowRate;
        uint64 fundingStartDate;
        uint256 fundingRemainder;
        uint256 subsidyRemainder;
    }

    //     ______           __                     ______
    //    / ____/_  _______/ /_____  ____ ___     / ____/_____________  __________
    //   / /   / / / / ___/ __/ __ \/ __ `__ \   / __/ / ___/ ___/ __ \/ ___/ ___/
    //  / /___/ /_/ (__  ) /_/ /_/ / / / / / /  / /___/ /  / /  / /_/ / /  (__  )
    //  \____/\__,_/____/\__/\____/_/ /_/ /_/  /_____/_/  /_/   \____/_/  /____/

    /// @notice Error thrown when attempting to add units to a non-existant locker
    /// @dev Error Selector :
    error LOCKER_NOT_FOUND();

    /// @notice Error thrown when attempting to stop a program's funding earlier than expected
    /// @dev Error Selector :
    error TOO_EARLY_TO_END_PROGRAM();

    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice Staking Reward Controller contract interface
    ISuperfluidPool public immutable TAX_DISTRIBUTION_POOL;

    /// @notice Program Duration used to calculate flow rates
    uint256 public constant PROGRAM_DURATION = 90 days;

    /// @notice Constant used to calculate the earliest date a program can be stopped
    uint256 public constant EARLY_PROGRAM_END = 7 days;

    /// @notice Basis points denominator (for percentage calculation)
    uint96 private constant _BP_DENOMINATOR = 10_000;

    /// @notice Superfluid Buffer basis calculation
    uint256 private constant _BUFFER_DURATION = 4 hours;

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
    mapping(uint256 programId => FluidProgramDetails programDetails) private _fluidProgramDetails;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Superfluid Ecosystem Partner Program Manager constructor
     * @param owner contract owner address
     */
    constructor(address owner, address treasury, ISuperfluidPool taxDistributionPool) Ownable(owner) {
        fluidTreasury = treasury;
        TAX_DISTRIBUTION_POOL = taxDistributionPool;
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
     * @notice Stop flows from this contract to the distribution pool and to the staking reserve
     * @param programId program identifier to cancel
     */
    function cancelProgram(uint256 programId) external onlyOwner {
        EPProgram memory program = programs[programId];
        FluidProgramDetails memory programDetails = _fluidProgramDetails[programId];

        // Ensure program exists or has not already been terminated
        if (programDetails.fundingStartDate == 0) revert IEPProgramManager.INVALID_PARAMETER();

        uint256 endDate = programDetails.fundingStartDate + PROGRAM_DURATION;

        uint256 undistributedFundingAmount;
        uint256 undistributedSubsidyAmount;

        if (endDate > block.timestamp) {
            undistributedFundingAmount =
                (endDate - block.timestamp) * uint96(programDetails.fundingFlowRate) + programDetails.fundingRemainder;
            undistributedSubsidyAmount =
                (endDate - block.timestamp) * uint96(programDetails.subsidyFlowRate) + programDetails.subsidyRemainder;
        }

        program.token.distributeFlow(address(this), program.distributionPool, 0);

        if (programDetails.subsidyFlowRate > 0) {
            // Decrease the subsidy flow to the tax distribution pool
            _decreaseSubsidyFlow(program.token, programDetails.subsidyFlowRate);
        }

        if (undistributedFundingAmount + undistributedSubsidyAmount > 0) {
            // Distribute the remainder to the program pool
            program.token.transfer(fluidTreasury, undistributedFundingAmount + undistributedSubsidyAmount);
        }

        // Delete the program details
        delete _fluidProgramDetails[programId];
    }

    /**
     * @notice Programatically calculate and initiate distribution to the GDA pools and staking reserve
     * @dev Only the contract owner can perform this operation
     * @param programId program identifier to start funding
     * @param totalAmount total amount to be distributed (including staking subsidy)
     */
    function startFunding(uint256 programId, uint256 totalAmount) external onlyOwner {
        EPProgram memory program = programs[programId];

        // Calculate the funding and subsidy amount
        uint256 subsidyAmount = (totalAmount * subsidyFundingRate) / _BP_DENOMINATOR;
        uint256 fundingAmount = totalAmount - subsidyAmount;

        // Calculate the funding and subsidy flow rates
        int96 subsidyFlowRate = int256(subsidyAmount / PROGRAM_DURATION).toInt96();
        int96 fundingFlowRate = int256(fundingAmount / PROGRAM_DURATION).toInt96();

        // TODO : Calculate accurate flow rates

        uint256 fundingRemainder =
            fundingAmount > 0 ? fundingAmount - (SafeCast.toUint256(fundingFlowRate) * PROGRAM_DURATION) : 0;

        uint256 subsidyRemainder =
            subsidyAmount > 0 ? subsidyAmount - (SafeCast.toUint256(subsidyFlowRate) * PROGRAM_DURATION) : 0;

        // Persist program details
        _fluidProgramDetails[programId] = FluidProgramDetails({
            fundingFlowRate: fundingFlowRate,
            subsidyFlowRate: subsidyFlowRate,
            fundingStartDate: uint64(block.timestamp),
            fundingRemainder: fundingRemainder,
            subsidyRemainder: subsidyRemainder
        });

        // Fetch funds from FLUID Treasury (requires prior approval from the Treasury)
        program.token.transferFrom(fluidTreasury, address(this), totalAmount);

        // Distribute flow to Program GDA pool
        program.token.distributeFlow(address(this), program.distributionPool, fundingFlowRate);

        if (subsidyFlowRate > 0) {
            // Create or update the subsidy flow to the Staking Reward Controller
            _increaseSubsidyFlow(program.token, subsidyFlowRate);
        }
    }

    /**
     * @notice Stop flows from this contract to the distribution pool and to the staking reserve
     * @param programId program identifier to stop funding
     */
    function stopFunding(uint256 programId) external {
        EPProgram memory program = programs[programId];
        FluidProgramDetails memory programDetails = _fluidProgramDetails[programId];

        // Ensure program exists or has not already been terminated
        if (programDetails.fundingStartDate == 0) revert IEPProgramManager.INVALID_PARAMETER();

        uint256 endDate = programDetails.fundingStartDate + PROGRAM_DURATION;

        // Ensure time window is valid to stop the funding
        if (block.timestamp < endDate - EARLY_PROGRAM_END) {
            revert TOO_EARLY_TO_END_PROGRAM();
        }

        uint256 earlyEndCompensation;
        uint256 subsidyEarlyEndCompensation;

        // if the program is stopped during its early end period, calculate the flow compensations
        if (endDate > block.timestamp) {
            earlyEndCompensation =
                (endDate - block.timestamp) * uint96(programDetails.fundingFlowRate) + (programDetails.fundingRemainder);
            subsidyEarlyEndCompensation =
                (endDate - block.timestamp) * uint96(programDetails.subsidyFlowRate) + (programDetails.subsidyRemainder);
        }

        // Stops the distribution flow to the program pool
        program.token.distributeFlow(address(this), program.distributionPool, 0);

        if (programDetails.subsidyFlowRate > 0) {
            // Delete or update the subsidy flow to the Staking Reward Controller
            _decreaseSubsidyFlow(program.token, programDetails.subsidyFlowRate);
        }

        if (earlyEndCompensation > 0) {
            // Distribute the remainder to the program pool
            program.token.distributeToPool(address(this), program.distributionPool, earlyEndCompensation);
        }

        if (subsidyEarlyEndCompensation > 0) {
            // Distribute the remainder to the stakers pool
            program.token.distributeToPool(address(this), TAX_DISTRIBUTION_POOL, subsidyEarlyEndCompensation);
        }

        // Delete the program details
        delete _fluidProgramDetails[programId];
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
        if (subsidyRate > _BP_DENOMINATOR) revert INVALID_PARAMETER();
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
    function _increaseSubsidyFlow(ISuperToken token, int96 subsidyFlowRateToIncrease)
        internal
        returns (int96 newSubsidyFlowRate)
    {
        // Fetch current flow between this contract and the tax distribution pool
        int96 currentSubsidyFlowRate = token.getFlowDistributionFlowRate(address(this), TAX_DISTRIBUTION_POOL);

        // Calculate the new subsidy flow rate
        newSubsidyFlowRate = currentSubsidyFlowRate + subsidyFlowRateToIncrease;

        // Update the distribution flow rate to the tax distribution pool
        token.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, newSubsidyFlowRate);
    }

    /**
     * @notice Delete or update the subsidy flow from this contract to the staking subsidy reserve
     * @param token token contract address
     * @param subsidyFlowRateToDecrease flow rate to deduce from the current global subsidy flow rate
     * @return newSubsidyFlowRate the new current global subsidy flow rate
     */
    function _decreaseSubsidyFlow(ISuperToken token, int96 subsidyFlowRateToDecrease)
        internal
        returns (int96 newSubsidyFlowRate)
    {
        // Fetch current flow between this contract and the tax distribution pool
        int96 currentSubsidyFlowRate = token.getFlowDistributionFlowRate(address(this), TAX_DISTRIBUTION_POOL);

        // Calculate the new subsidy flow rate
        newSubsidyFlowRate = currentSubsidyFlowRate <= subsidyFlowRateToDecrease
            ? int96(0)
            : currentSubsidyFlowRate - subsidyFlowRateToDecrease;

        // Update the distribution flow rate to the tax distribution pool
        token.distributeFlow(address(this), TAX_DISTRIBUTION_POOL, newSubsidyFlowRate);
    }
}
