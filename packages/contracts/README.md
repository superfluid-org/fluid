## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

## Address Registry :

Latest deployed contract address

### ETHEREUM SEPOLIA :

| Contract           | Address                                    | Explorer                                                                        |
| ------------------ | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken (ERC20) | 0xe1F66A06c08911203e093303Eb9Ff07EdbFFe030 | https://sepolia.etherscan.io/address/0xe1F66A06c08911203e093303Eb9Ff07EdbFFe030 |

### BASE SEPOLIA :

| Contract                        | Address                                    | Explorer                                                                        |
| ------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken (SuperToken)         | 0xFd62b398DD8a233ad37156690631fb9515059d6A | https://sepolia.basescan.org/address/0xFd62b398DD8a233ad37156690631fb9515059d6A |
| FluidEPProgramManager (Logic)   | 0xE1061135B65dc63CB6957399bd524828Cdaa580D | https://sepolia.basescan.org/address/0xE1061135B65dc63CB6957399bd524828Cdaa580D |
| FluidEPProgramManager (Proxy)   | 0xA8f867fA115f64F9728Fc4fd4Ce959f12442a86E | https://sepolia.basescan.org/address/0xA8f867fA115f64F9728Fc4fd4Ce959f12442a86E |
| StakingRewardController (Logic) | 0xAe665c8154B15Bf4F7a3f813dB71D40624b7Dac7 | https://sepolia.basescan.org/address/0xAe665c8154B15Bf4F7a3f813dB71D40624b7Dac7 |
| StakingRewardController (Proxy) | 0xC2569d417f3f255b30966D21EB31fFCb76b05150 | https://sepolia.basescan.org/address/0xC2569d417f3f255b30966D21EB31fFCb76b05150 |
| FluidLocker (Logic)             | 0x68268914dE6eB7077C941125815DB2057238078A | https://sepolia.basescan.org/address/0x68268914dE6eB7077C941125815DB2057238078A |
| FluidLocker (Beacon)            | 0xa67d2E26843793048990e3e8e0e7120Eb3cc8ad8 | https://sepolia.basescan.org/address/0xa67d2E26843793048990e3e8e0e7120Eb3cc8ad8 |
| Fontaine (Logic)                | 0xf8dA8dF03A567FBc1A4e567bdA7C3883e6E674bB | https://sepolia.basescan.org/address/0xf8dA8dF03A567FBc1A4e567bdA7C3883e6E674bB |
| Fontaine (Beacon)               | 0xC853A70737259e245582Dd03947b49BD39BB2044 | https://sepolia.basescan.org/address/0xC853A70737259e245582Dd03947b49BD39BB2044 |
| FluidLockerFactory (Logic)      | 0xd24f152086b2cd2BB4617cadd76c58C6dEFa3b94 | https://sepolia.basescan.org/address/0xd24f152086b2cd2BB4617cadd76c58C6dEFa3b94 |
| FluidLockerFactory (Proxy)      | 0x9ecF49AC7E0F42B4D272dC95Cbfe0119454B1988 | https://sepolia.basescan.org/address/0x9ecF49AC7E0F42B4D272dC95Cbfe0119454B1988 |

## Test Coverage :

Current test coverage is as follow :

| File                                     | % Lines             | % Statements       | % Branches        | % Funcs           |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/EPProgramManager.sol                 | 100.00% (55/55)     | 100.00% (56/56)    | 100.00% (14/14)   | 100.00% (13/13)   |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/FluidEPProgramManager.sol            | 95.74% (90/94)      | 98.00% (98/100)    | 100.00% (20/20)   | 86.67% (13/15)    |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/FluidLocker.sol                      | 100.00% (100/100)   | 98.04% (100/102)   | 87.50% (14/16)    | 100.00% (21/21)   |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/FluidLockerFactory.sol               | 83.87% (26/31)      | 80.95% (17/21)     | 0.00% (0/2)       | 81.82% (9/11)     |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/Fontaine.sol                         | 100.00% (25/25)     | 96.00% (24/25)     | 80.00% (4/5)      | 100.00% (3/3)     |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/StakingRewardController.sol          | 91.67% (22/24)      | 94.44% (17/18)     | 100.00% (3/3)     | 87.50% (7/8)      |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/TreasuryGadget.sol                   | 100.00% (18/18)     | 100.00% (12/12)    | 100.00% (2/2)     | 100.00% (6/6)     |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/token/BridgedSuperToken.sol          | 98.48% (65/66)      | 98.46% (64/65)     | 90.00% (9/10)     | 100.00% (13/13)   |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/token/FluidToken.sol                 | 0.00% (0/6)         | 0.00% (0/4)        | 100.00% (0/0)     | 0.00% (0/3)       |
| ---------------------------------------- | ------------------- | ------------------ | ----------------- | ----------------- |
| src/token/OPBridgedSuperToken.sol        | 71.43% (10/14)      | 84.62% (11/13)     | 100.00% (0/0)     | 66.67% (4/6)      |

## Deployment Procedure

### Step 1 - ETH Mainnet Token Deployment

```shell
OWNER={DEPLOYER_ADDRESS} \
INITIAL_SUPPLY=1000000000000000000000000000 \
forge script script/token/DeploySupToken.s.sol:DeployL1SupToken --ffi --rpc-url ${ETH_MAINNET_RPC_URL} --broadcast -vvv --verify --etherscan-api-key ${ETHERSCAN_API_KEY}
```

### Step 2 - Transfer 650M $SUP to Foundation Multisig (L1)

> NOTE : `transfer(address,uint256) args : sender, amount`

```shell
cast send --rpc-url {ETH_MAINNET_RPC_URL} {L1_FLUID_TOKEN_ADDRESS} "transfer(address,uint256)" {FOUNDATION_MULTISIG_ADDRESS} 650000000000000000000000000 --private-key $PRIVATE_KEY
```

### Step 3 - Base Token Deployment

```shell
OWNER={FOUNDATION_MULTISIG_ADDRESS} \
INITIAL_SUPPLY=0 \
REMOTE_TOKEN={L1_FLUID_TOKEN_ADDRESS} \
NATIVE_BRIDGE={NATIVE_BRIDGE} \
SUPERTOKEN_FACTORY={BASE_MAINNET_SUPERTOKEN_FACTORY} \
forge script script/DeployFluidToken.s.sol:DeployOPFluidSuperToken --ffi --rpc-url {BASE_MAINNET_RPC_URL} --broadcast -vvv
```

### Step 4 - Bridge 350M $FLUID to Base ($FLUID on L1 -> $FLUIDx on Base L2)

#### Approve the bridge contract

> NOTE : `approve(address,uint256) args : spender, allowance`

```shell
cast send --rpc-url $ETH_MAINNET_RPC_URL {L1_FLUID_TOKEN_ADDRESS} "approve(address,uint256)" {L1_BRIDGE_ADDRESS} 350000000000000000000000000 --private-key $PRIVATE_KEY
```

#### Bridge the tokens

> NOTE : `bridgeERC20(address,address,uint256,uint32,bytes) args : tokenAddressL1, tokenAddressL2, amount, gasLimit, data`

```shell
cast send --rpc-url $ETH_MAINNET_RPC_URL {L1_BRIDGE_ADDRESS} "bridgeERC20(address,address,uint256,uint32,bytes)" {L1_FLUID_TOKEN_ADDRESS} {L2_FLUID_TOKEN_ADDRESS} 350000000000000000000000000 10000000 0x --private-key $PRIVATE_KEY
```

### Step 5 - Transfer 350M $FLUID to Community Multisig (L2)

> NOTE : `transfer(address,uint256) args : sender, amount`

```shell
cast send --rpc-url $BASE_MAINNET_RPC_URL {L2_FLUID_TOKEN_ADDRESS} "transfer(address,uint256)" {COMMUNITY_MULTISIG_ADDRESS} 350000000000000000000000000 --private-key $PRIVATE_KEY
```

### Step 6 - Locker Contract System Deployment

```shell
FLUID_ADDRESS={L2_FLUID_TOKEN_ADDRESS} \
GOVERNOR_ADDRESS={COMMUNITY_MULTISIG_ADDRESS} \
TREASURY_ADDRESS={COMMUNITY_MULTISIG_ADDRESS} \
PAUSE_FACTORY_LOCKER_CREATION=false \
FLUID_UNLOCK_STATUS=true \
forge script script/Deploy.s.sol:DeployScript --ffi --rpc-url $BASE_MAINNET_RPC_URL --broadcast -vvv
```

### References

```
HOST_ADDRESS : Superfluid Host address
FLUID_ADDRESS : SuperToken to be distributed
GOVERNOR_ADDRESS : Contract owner address
TREASURY_ADDRESS : Treasury address holding the SuperToken to be distributed
STACK_SIGNER_ADDRESS : Signer address to be verified in order to grant units
PAUSE_FACTORY_LOCKER_CREATION : Whether the Factory allows Lockers to be created or not
FLUID_UNLOCK_STATUS : Whether the Lockers allow the SuperToken to be withdrawn or not
```
