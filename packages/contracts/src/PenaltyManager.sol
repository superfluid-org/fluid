pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */
import {Ownable} from "@openzeppelin-v5/contracts/access/Ownable.sol";

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluidPool, ISuperToken, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {IPenaltyManager} from "./interfaces/IPenaltyManager.sol";

using SuperTokenV1Library for ISuperToken;

contract PenaltyManager is Ownable, IPenaltyManager {
    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable PENALTY_DRAINING_POOL;

    address public immutable LOCKER_FACTORY;

    mapping(address locker => bool isApproved) private _approvedLockers;

    constructor(
        address owner,
        address lockerFactory,
        ISuperToken fluid
    ) Ownable(owner) {
        FLUID = fluid;
        LOCKER_FACTORY = lockerFactory;

        // Configure Superfluid GDA Pool
        PoolConfig memory poolConfig = PoolConfig({
            transferabilityForUnitsOwner: false,
            distributionFromAnyAddress: true
        });

        // Create Superfluid GDA Pool
        PENALTY_DRAINING_POOL = fluid.createPool(address(this), poolConfig);
    }

    function updateStakerUnits(uint256 lockerStakedBalance) external {
        if (!_approvedLockers[msg.sender]) revert NOT_APPROVED_LOCKER();

        /// FIXME Find proper stakedBalance to GDA pool units calculation
        FLUID.updateMemberUnits(
            PENALTY_DRAINING_POOL,
            msg.sender,
            uint128(lockerStakedBalance)
        );
    }
    function updateLiquidityProvidersUnits(uint256 liquidityProvided) external {
        if (!_approvedLockers[msg.sender]) revert NOT_APPROVED_LOCKER();

        /// FIXME Find proper liquidity provided to GDA pool units calculation
        FLUID.updateMemberUnits(
            PENALTY_DRAINING_POOL,
            msg.sender,
            uint128(liquidityProvided)
        );
    }

    function approveLocker(address lockerAddress) external {
        if (msg.sender != LOCKER_FACTORY) revert NOT_LOCKER_FACTORY();
        _approvedLockers[lockerAddress] = true;
    }
}
