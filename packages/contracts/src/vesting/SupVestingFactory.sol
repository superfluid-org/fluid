// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Superfluid Protocol Contracts & Interfaces */
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { IVestingSchedulerV2 } from
    "@superfluid-finance/automation-contracts/scheduler/contracts/interface/IVestingSchedulerV2.sol";

/* SUP Token Vesting Interfaces */
import { ISupVestingFactory } from "../interfaces/vesting/ISupVestingFactory.sol";
import { SupVesting } from "./SupVesting.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title SUP Token Vesting Factory Contract
 * @author Superfluid
 * @notice Contract deploying new SUP Token Vesting contracts
 */
contract SupVestingFactory is ISupVestingFactory {
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice Superfluid Vesting Scheduler contract address
    IVestingSchedulerV2 public immutable VESTING_SCHEDULER;

    /// @notice SUP Token contract address
    ISuperToken public immutable SUP;

    //     _____ __        __
    //    / ___// /_____ _/ /____  _____
    //    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   ___/ / /_/ /_/ / /_/  __(__  )
    //  /____/\__/\__,_/\__/\___/____/

    /// @notice Name of the Locked SUP Token
    string public name;

    /// @notice Symbol of the Locked SUP Token
    string public symbol;

    /// @notice Foundation treasury address
    address public treasury;

    /// @notice Foundation admin address
    address public admin;

    /// @notice Mapping of recipient addresses to their corresponding SUP Token Vesting contracts
    mapping(address recipient => address supVesting) public supVestings;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice SupVestingFactory contract constructor
     * @param vestingScheduler The Superfluid vesting scheduler contract
     * @param token The SUP token contract
     * @param treasuryAddress The foundation treasury address
     * @param adminAddress The foundation admin address
     */
    constructor(
        IVestingSchedulerV2 vestingScheduler,
        ISuperToken token,
        address treasuryAddress,
        address adminAddress
    ) {
        // Persist state variables
        VESTING_SCHEDULER = vestingScheduler;
        SUP = token;
        treasury = treasuryAddress;
        admin = adminAddress;
        name = "Locked SUP Token";
        symbol = "lockedSUP";
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc ISupVestingFactory
    function createSupVestingContract(
        address recipient,
        uint256 amount,
        uint32 duration,
        uint32 startDate,
        uint32 cliffPeriod,
        bool isPrefunded
    ) external returns (address newSupVestingContract) {
        // Deploy the new SUP Token Vesting contract
        newSupVestingContract =
            address(new SupVesting(VESTING_SCHEDULER, SUP, recipient, amount, duration, startDate, cliffPeriod));

        // Maps the recipient address to the new SUP Token Vesting contract
        supVestings[recipient] = newSupVestingContract;

        // If the vesting contract is prefunded, transfer the tokens from the treasury to the new vesting contract
        if (isPrefunded) {
            SUP.transferFrom(treasury, newSupVestingContract, amount);
        }

        // Emit the events
        emit Transfer(address(0), recipient, amount);
        emit SupVestingCreated(recipient, newSupVestingContract);
    }

    /// @inheritdoc ISupVestingFactory
    function setTreasury(address newTreasury) external onlyAdmin {
        // Ensure the new treasury address is not the zero address
        if (newTreasury == address(0)) revert FORBIDDEN();
        treasury = newTreasury;
    }

    /// @inheritdoc ISupVestingFactory
    function setAdmin(address newAdmin) external onlyAdmin {
        // Ensure the new admin address is not the zero address
        if (newAdmin == address(0)) revert FORBIDDEN();
        admin = newAdmin;
    }

    //   _    ___                 ______                 __  _
    //  | |  / (_)__ _      __   / ____/_  ______  _____/ /_(_)___  ____  _____
    //  | | / / / _ \ | /| / /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //  | |/ / /  __/ |/ |/ /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  |___/_/\___/|__/|__/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc ISupVestingFactory
    function balanceOf(address vestingReceiver) external view returns (uint256 unvestedBalance) {
        // Get the flow buffer amount
        (,, uint256 deposit,) = SUP.getFlowInfo(supVestings[vestingReceiver], vestingReceiver);

        unvestedBalance = SUP.balanceOf(supVestings[vestingReceiver]) + deposit;
    }

    //      __  ___          ___ _____
    //     /  |/  /___  ____/ (_) __(_)__  __________
    //    / /|_/ / __ \/ __  / / /_/ / _ \/ ___/ ___/
    //   / /  / / /_/ / /_/ / / __/ /  __/ /  (__  )
    //  /_/  /_/\____/\__,_/_/_/ /_/\___/_/  /____/

    /**
     * @notice Modifier to restrict access to admin only
     */
    modifier onlyAdmin() {
        if (msg.sender != admin) revert FORBIDDEN();
        _;
    }
}
