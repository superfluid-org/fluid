# SPR SUP Reserve System - User Guide

## Overview

This document provides a technical overview of the Reserve mechanism.

## Definitions

- [SUP Token](https://forum.superfluid.org/t/superfluid-dao-governance-and-tokenomics/69)
- [SPR](https://forum.superfluid.org/t/superfluid-dao-governance-and-tokenomics/69)
- [Reserves](https://forum.superfluid.org/t/superfluid-dao-governance-and-tokenomics/69)
- [Community Charge](https://forum.superfluid.org/t/superfluid-dao-governance-and-tokenomics/69)

## System Architecture

The SPR SUP Reserve System consists of several key components:

### Core Contracts

1. **FluidLockerFactory** - Creates individual reserve contracts for users
2. **FluidLocker** - Personal reserve where users store and manage their SUP tokens
3. **StakingRewardController** - Manages staking rewards and Community Charge distribution
4. **FluidEPProgramManager** - Administers ecosystem partner reward programs
5. **Fontaine** - Handles gradual token withdrawal through streaming

### Key Features

- **Reward Programs**: Participate in ecosystem partner programs
- **Liquidity Provision**: Provide liquidity to earn rewards & trading fees
- **Staking**: Earn rewards by staking SUP tokens
- **Vest Withdrawing**: Withdraw tokens over time with reduced penalties
- **Instant Withdrawing**: Withdraw tokens instantly with high penalty
- **Token Locking**: Get yield from your SUP tokens

## Getting Started

### Step 1: Create Your Reserve

Before you can use the SPR SUP Reserve System, you need to create your personal reserve.

**Cost**: A small fee is required to create a reserve (set by governance)

**Result**: You get a unique reserve contract address that only you can control

### Step 2: Participate in Reward Programs

You can participate in reward programs to earn SUP tokens. Use the ecosystem partner apps and claim your SUP flow rate daily.

### Step 3: Lock Your SUP Tokens (optional)

Once you have a reserve, you can lock additional SUP tokens to earn additional rewards

**Benefits of Locking**:

- You can stake them to earn rewards
- You can provide liquidity

## Core Functions

### Reward Programs

The system supports ecosystem partner programs where you can earn SUP tokens.
You can participate in the currently live campaigns on [Superfluid Claim App](https://claim.superfluid.org).
As your participation in the campaigns increases, you are entitled to claim a higher SUP flow rate by claiming it daily.

### Withdrawing SUP Tokens

You can withdraw your SUP tokens in two ways:

#### 1. Instant Withdraw (High Penalty)

You can withdraw your SUP tokens instantly. Chosing this option will allow you to get your SUP tokens instantly to your wallet, however you will have to pay a high penalty.

**Penalty**: 80% of the withdrawn amount goes to stakers and liquidity providers

#### 2. Vest Withdraw (Reduced Penalty)

You can withdraw your SUP tokens gradually. Chosing this option will allow you to get your SUP tokens streamed to your wallet over the period of your choice. You will be subject to penalty based on the duration of the chosen withdraw period.

**Penalty Calculation**:

- Minimum Withdraw Period: 7 days
- Maximum Withdraw Period: 365 days
- Penalty decreases with longer withdraw periods

**Example Penalties**:

- 7 days: ~70% penalty
- 30 days: ~60% penalty
- 90 days: ~40% penalty
- 180 days: ~25% penalty
- 365 days: 0% penalty

### Staking

Staking allows you to earn rewards from the penalties collected when other users withdraw their tokens.

#### How to Stake

**Requirements**:

- You must have available SUP tokens in your Reserve

**Note**: After staking, there's a 7-days cooldown before you can unstake
**Note**: The 7-days cooldown period is reset at every staking event

#### How to Unstake

**Requirements**:

- 7-day cooldown period must have elapsed

#### How to Claim Staking Rewards

Staking rewards are streamed directly to your Reserve. You do not have to claim them, however, you may have to stake them to increase your share of the rewards.

### Liquidity Provision

You can provide liquidity to the ETH/SUP Uniswap V3 pool to earn trading fees and a share of the penalties collected when other users withdraw their tokens.

#### How to Provide Liquidity

You can provide liquidity by sender ETH to your Reserve and calling the provide liquidity function.
Every time you provide liquidity a new Uniswap V3 position is created. The corresponding NFT is stored in your Reserve.

**Requirements**:

- Send the required ETH amount along with the transaction
- Have enough SUP tokens in your Reserve

**Note**: After providing liquidity, there's a 7-day cooldown before you can withdraw your liquidity
**Note**: The 7-days cooldown is position specific (i.e. different positions may have different cooldown end dates)

#### How to Collect Fees

You can collect fees from your liquidity positions at any time. The fees generated from your liquidity position are instantly transferred to your wallet.

#### How to Withdraw Liquidity

You can withdraw your Reserve's Uniswap V3 position either partially or fully.

**Requirements**:

- 7-day cooldown period must have elapsed

##### Community Charge-Free Withdrawals (Liquidity Provision)

After providing liquidity for 180 days, you can withdraw your position and get your SUP (and ETH) tokens directly to your wallet without paying the Reserve Community Charge.

###### How Community Charge-Free Withdrawals Work

When you provide liquidity to the ETH/SUP Uniswap V3 pool through your Reserve, a timestamp is recorded for that position. After 180 days (6 months) from the initial liquidity provision, you become eligible for Community Charge-free withdrawals.

**Key Benefits:**

- **No Penalty**: Withdraw your SUP tokens without paying the usual Community Charge
- **Full Value**: Get the complete value of your position without deductions
- **Reward Retention**: Keep all accumulated trading fees and rewards

**Requirements:**

- Position must have been created at least 180 days ago
- You must be the owner of the Reserve that created the position
- Position must still exist and be active

**Important Notes:**

- The 180-day timer starts from when you first provide liquidity to a position
- Each position has its own independent 180-day timer
- Community Charge-free withdrawal only applies to the SUP tokens in your liquidity position, not to staked tokens
- You can still collect trading fees at any time without affecting the Community Charge-free withdrawal eligibility

**Example Timeline:**

1. **Day 0**: Provide liquidity to ETH/SUP pool
2. **Day 1-179**: Collect trading fees, position not eligible for Community Charge-free withdrawal
3. **Day 180+**: Position becomes eligible for Community Charge-free withdrawal
4. **Any time after Day 180**: Withdraw your SUP tokens directly to your wallet without penalties

## Token Management

### Available Balance

Your available balance is the amount of SUP tokens you can use for:

- Staking
- Providing liquidity
- Withdrawing

### Staked Balance

Your staked balance represents tokens that are earning staking rewards but cannot be used for other purposes until unstaked.

### Liquidity Balance

Your liquidity balance represents the size of all your Reserves' liquidity positions in the ETH/SUP pool.

## Important Considerations

### Security

- Only you can control your Reserve
- All operations on your Reserve require your signature

### Fees and Penalties

- **Reserve Creation**: One-time fee set by governance
- **Instant Withdraw**: 80% penalty
- **Gradual Withdraw**: Variable penalty based on duration

### Limitations

- **Minimum Withdraw Amount**: 10 SUP tokens
- **Minimum Withdraw Period**: 7 days
- **Maximum Withdraw Period**: 365 days
- **Unstaking Cooldown**: 7 days after last staking event
- **Liquidity Provision Withdrawal**: 7 days after providing liquidity

---

_This guide covers the main user interactions with the SPR SUP Reserve System. For technical details and contract specifications, refer to the contract source code and interfaces._
