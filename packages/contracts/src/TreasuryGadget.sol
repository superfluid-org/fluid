// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/* Superfluid Protocol Contracts & Interfaces */
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/* Openzeppelin Contracts & Interfaces */
import { Ownable } from "@openzeppelin-v5/contracts/access/Ownable.sol";

/* FLUID Interfaces */
import { ITreasuryGadget } from "./interfaces/ITreasuryGadget.sol";

using SuperTokenV1Library for ISuperToken;

/**
 * @title Treasury Gadget Contract
 * @author Superfluid
 * @notice Contract responsible for funding the community multisig
 */
contract TreasuryGadget is ITreasuryGadget, Ownable {
    //      ____                          __        __    __        _____ __        __
    //     /  _/___ ___  ____ ___  __  __/ /_____ _/ /_  / /__     / ___// /_____ _/ /____  _____
    //     / // __ `__ \/ __ `__ \/ / / / __/ __ `/ __ \/ / _ \    \__ \/ __/ __ `/ __/ _ \/ ___/
    //   _/ // / / / / / / / / / / /_/ / /_/ /_/ / /_/ / /  __/   ___/ / /_/ /_/ / /_/  __(__  )
    //  /___/_/ /_/ /_/_/ /_/ /_/\__,_/\__/\__,_/_.___/_/\___/   /____/\__/\__,_/\__/\___/____/

    /// @notice $FLUID SuperToken interface
    ISuperToken public immutable FLUID;

    /// @notice Community Multisig address
    address public immutable COMMUNITY_MULTISIG;

    /// @notice Foundation Multisig address
    address public immutable FOUNDATION_MULTISIG;

    //     ______                 __                  __
    //    / ____/___  ____  _____/ /________  _______/ /_____  _____
    //   / /   / __ \/ __ \/ ___/ __/ ___/ / / / ___/ __/ __ \/ ___/
    //  / /___/ /_/ / / / (__  ) /_/ /  / /_/ / /__/ /_/ /_/ / /
    //  \____/\____/_/ /_/____/\__/_/   \__,_/\___/\__/\____/_/

    /**
     * @notice Treasury Gadget Constructor
     * @param fluid $FLUID SuperToken interface
     * @param communityMultisig Community Multisig address
     * @param foundationMultisig Foundation Multisig address
     */
    constructor(ISuperToken fluid, address communityMultisig, address foundationMultisig) Ownable(foundationMultisig) {
        FLUID = fluid;
        COMMUNITY_MULTISIG = communityMultisig;
    }

    //      ______     __                        __   ______                 __  _
    //     / ____/  __/ /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //    / __/ | |/_/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   / /____>  </ /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /_____/_/|_|\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /// @inheritdoc ITreasuryGadget
    function fundCommunityMultisig(uint256 totalAmount, uint256 cliffAmount, int96 flowRate) external onlyOwner {
        if (cliffAmount > totalAmount) {
            revert INVALID_PARAMETER();
        }
        // Transfer total amount to this contract
        FLUID.transferFrom(msg.sender, address(this), totalAmount);

        if (cliffAmount > 0) {
            // Transfer the cliff amount to the community multisig
            FLUID.transfer(COMMUNITY_MULTISIG, cliffAmount);
        }

        // Set up the flow
        FLUID.flow(COMMUNITY_MULTISIG, flowRate);
    }

    /// @inheritdoc ITreasuryGadget
    function updateFunding(int96 newFlowRate) external onlyOwner {
        FLUID.flow(COMMUNITY_MULTISIG, newFlowRate);
    }

    /// @inheritdoc ITreasuryGadget
    function withdraw(uint256 amount) external onlyOwner {
        _withdraw(amount);
    }

    /// @inheritdoc ITreasuryGadget
    function withdrawAll() external onlyOwner {
        _withdraw(FLUID.balanceOf(address(this)));
    }

    //      ____      __                        __   ______                 __  _
    //     /  _/___  / /____  _________  ____ _/ /  / ____/_  ______  _____/ /_(_)___  ____  _____
    //     / // __ \/ __/ _ \/ ___/ __ \/ __ `/ /  / /_  / / / / __ \/ ___/ __/ / __ \/ __ \/ ___/
    //   _/ // / / / /_/  __/ /  / / / / /_/ / /  / __/ / /_/ / / / / /__/ /_/ / /_/ / / / (__  )
    //  /___/_/ /_/\__/\___/_/  /_/ /_/\__,_/_/  /_/    \__,_/_/ /_/\___/\__/_/\____/_/ /_/____/

    /**
     * @notice Internal function to withdraw FLUID tokens from this contract back to the owner
     * @param amount Amount of FLUID tokens to withdraw
     */
    function _withdraw(uint256 amount) internal {
        FLUID.transfer(msg.sender, amount);
    }
}
