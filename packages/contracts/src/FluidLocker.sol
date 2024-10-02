pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluid, ISuperfluidPool, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

using SuperTokenV1Library for ISuperToken;

/**
DESIGN Questions :
- Are we OK to allow draining of staking reward?
    If YES :
        - will need to support multiple concurrent drains (i.e. User drains 10 FLUID at t1, User drains 20 FLUID at t2)
    If NOT : 
        - will need to implement logic as follow : 
            ```if (stakedBalance > 0) revert CANNOT_DRAIN_WHILE_STAKING();```

 */

contract FluidLocker {
    /// FIXME storage packing

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Superfluid pool interface
    ISuperfluidPool public immutable GDA_POOL;

    /// @notice This locker owner address
    address public lockerOwner;

    /// @notice Minimum drain period allowed
    uint128 private constant _MIN_DRAIN_PERIOD = 7 days;

    /// @notice Maximum drain period allowed
    uint128 private constant _MAX_DRAIN_PERIOD = 540 days;

    /// @notice Instant drain penalty percentage (expressed in basis points)
    uint256 private constant _INSTANT_DRAIN_PENALTY_BP = 8_000;

    /// @notice Basis points denominator (for percentage calculation)
    uint256 private constant _BP_DENOMINATOR = 10_000;

    /// @notice Balance of $FLUID staked in this locker
    uint256 private stakedBalance;

    /// FIXME : Move to IFluidLocker
    /// @notice Error thrown when the caller is not the owner
    error NOT_LOCKER_OWNER();

    /// @notice Error thrown when attempting to perform a forbidden operation
    error FORBIDDEN();

    /// @notice Error thrown when attempting to drain this locker with an invalid drain period
    error INVALID_DRAIN_PERIOD();

    /// @notice Error thrown when attempting to drain a locker that does not have available $FLUID
    error NO_FLUID_TO_DRAIN();

    constructor(ISuperToken fluid, ISuperfluidPool gdaPool) {
        FLUID = fluid;
        GDA_POOL = gdaPool;
    }

    function initialize(address owner) external {
        lockerOwner = owner;
    }

    function lock(uint256 amount) external {
        FLUID.transferFrom(msg.sender, address(this), amount);
    }

    function drain(uint128 drainPeriod) external onlyOwner {
        // Enforce drain period validity
        if (
            (drainPeriod != 0 && drainPeriod < _MIN_DRAIN_PERIOD) ||
            drainPeriod > _MAX_DRAIN_PERIOD
        ) revert INVALID_DRAIN_PERIOD();

        // get balance available for draining
        uint256 availableBalance = getAvailableBalance();

        // revert if there is nothing to drain
        if (availableBalance == 0) revert NO_FLUID_TO_DRAIN();

        if (drainPeriod == 0) {
            _instantDrain(availableBalance);
        } else {
            _vestDrain(availableBalance, drainPeriod);
        }
    }

    function _instantDrain(uint256 amountToDrain) internal {
        // Calculate instant drain penalty amount
        uint256 penaltyAmount = (amountToDrain * _INSTANT_DRAIN_PENALTY_BP) /
            _BP_DENOMINATOR;

        // Distribute penalty to staker (connected to the GDA_POOL)
        FLUID.distributeToPool(address(this), GDA_POOL, penaltyAmount);

        // Transfer the leftover $FLUID to the locker owner
        FLUID.transfer(msg.sender, amountToDrain - penaltyAmount);

        /// FIXME emit `drained locker` event
    }

    function _vestDrain(uint256 amountToDrain, uint128 drainPeriod) internal {}

    function stake() external onlyOwner {}

    function unstake() external onlyOwner {}

    function transferLocker(address recipient) external onlyOwner {
        if (recipient == address(0)) revert FORBIDDEN();
        lockerOwner = recipient;

        /// FIXME emit ownership transferred event
    }

    function getStakedBalance() external view returns (uint256 sBalance) {
        sBalance = stakedBalance;
    }

    function getAvailableBalance() public view returns (uint256 aBalance) {
        aBalance = FLUID.balanceOf(address(this)) - stakedBalance;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        if (msg.sender != lockerOwner) revert NOT_LOCKER_OWNER();
        _;
    }
}
