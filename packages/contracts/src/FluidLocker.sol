pragma solidity ^0.8.26;

/* Openzeppelin Contracts & Interfaces */

/* Superfluid Protocol Contracts & Interfaces */
import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

using SuperTokenV1Library for ISuperToken;

contract FluidLocker {
    ISuperToken public immutable FLUID;
    address public lockerOwner;

    error NOT_LOCKER_OWNER();
    error FORBIDDEN();

    constructor(ISuperToken _fluid) {
        FLUID = _fluid;
    }

    function initialize(address owner) external {
        lockerOwner = owner;
    }

    function lock(uint256 amount) external {
        FLUID.transferFrom(msg.sender, address(this), amount);
    }
    function drain() external onlyOwner {}
    function stake() external onlyOwner {}
    function unstake() external onlyOwner {}

    function transferLocker(address recipient) external onlyOwner {
        if (recipient == address(0)) revert FORBIDDEN();
        lockerOwner = recipient;

        /// TODO emit ownership transferred event
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        if (msg.sender != lockerOwner) revert NOT_LOCKER_OWNER();
        _;
    }
}
