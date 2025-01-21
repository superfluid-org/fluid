// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";
import { SupVesting } from "src/vesting/SupVesting.sol";

using SuperTokenV1Library for ISuperToken;

contract SupVestingFactory {
    IVestingSchedulerV2 public immutable VESTING_SCHEDULER;
    ISuperToken public immutable SUP;
    address public treasury;
    address public admin;

    string public name;
    string public symbol;

    mapping(address recipient => address supVesting) public supVestings;

    // Error thrown when the caller is not the foundation treasury
    error FORBIDDEN();

    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor(
        IVestingSchedulerV2 vestingScheduler,
        ISuperToken token,
        address treasuryAddress,
        address adminAddress
    ) {
        // Persist immutable addresses
        VESTING_SCHEDULER = vestingScheduler;
        SUP = token;
        treasury = treasuryAddress;
        admin = adminAddress;

        name = "Locked SUP Token";
        symbol = "lockedSUP";
    }

    function createSupVestingContract(
        address recipient,
        uint256 amount,
        uint32 duration,
        uint32 startDate,
        uint32 cliffPeriod,
        bool isPrefunded
    ) external returns (address newSupVestingContract) {
        newSupVestingContract = address(
            new SupVesting(VESTING_SCHEDULER, SUP, treasury, recipient, amount, duration, startDate, cliffPeriod)
        );

        supVestings[recipient] = newSupVestingContract;

        /// FIXME : do we want this ? Prefunded or Not ?
        if (isPrefunded) {
            SUP.transferFrom(treasury, newSupVestingContract, amount);
        }

        emit Transfer(address(0), recipient, amount);
    }

    function setTreasury(address newTreasury) external onlyAdmin {
        treasury = newTreasury;
    }

    function setAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    function balanceOf(address vestingReceiver) public view returns (uint256) {
        (,, uint256 deposit,) = SUP.getFlowInfo(supVestings[vestingReceiver], vestingReceiver);

        return SUP.balanceOf(supVestings[vestingReceiver]) + deposit;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert FORBIDDEN();
        _;
    }
}
