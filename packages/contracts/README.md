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
| FluidToken (ERC20) | 0x50De94359BdCAE78674e6918519DF0220aEfD514 | https://sepolia.etherscan.io/address/0x50De94359BdCAE78674e6918519DF0220aEfD514 |

### BASE SEPOLIA :

| Contract                        | Address                                    | Explorer                                                                        |
| ------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken (SuperToken)         | 0x8366107974417E0e611fAbc8C38BeCbE199d502a | https://sepolia.basescan.org/address/0x8366107974417E0e611fAbc8C38BeCbE199d502a |
| FluidEPProgramManager (Logic)   | 0xf304464faAFD0F61d8048e410d75F9884696Fcc0 | https://sepolia.basescan.org/address/0xf304464faAFD0F61d8048e410d75F9884696Fcc0 |
| FluidEPProgramManager (Proxy)   | 0x724639D7525Cb68b227E5C40399d73d9590E88Ca | https://sepolia.basescan.org/address/0x724639D7525Cb68b227E5C40399d73d9590E88Ca |
| StakingRewardController (Logic) | 0x7dB7683D2BdB443189d9C439cB5961faD47C1789 | https://sepolia.basescan.org/address/0x7dB7683D2BdB443189d9C439cB5961faD47C1789 |
| StakingRewardController (Proxy) | 0xAEe3b4d79917796821d3D0FE67554AD63c07242E | https://sepolia.basescan.org/address/0xAEe3b4d79917796821d3D0FE67554AD63c07242E |
| FluidLocker (Logic)             | 0x29f88faC9464b2A356a286ED6bB52E554BD28B82 | https://sepolia.basescan.org/address/0x29f88faC9464b2A356a286ED6bB52E554BD28B82 |
| FluidLocker (Beacon)            | 0x967DB599E3F13c1D3DBf5681dc28d9739736f7b5 | https://sepolia.basescan.org/address/0x967DB599E3F13c1D3DBf5681dc28d9739736f7b5 |
| Fontaine (Logic)                | 0x2189FdFa41804D99a6D3BE6be01Ef0926ab54d9b | https://sepolia.basescan.org/address/0x2189FdFa41804D99a6D3BE6be01Ef0926ab54d9b |
| Fontaine (Beacon)               | 0x1e9Ab15E663eA710241e786F5c2611E42011cfBC | https://sepolia.basescan.org/address/0x1e9Ab15E663eA710241e786F5c2611E42011cfBC |
| FluidLockerFactory (Logic)      | 0x99B6822ce3E201F7D8B8A3e50DF3C689c90Afa79 | https://sepolia.basescan.org/address/0x99B6822ce3E201F7D8B8A3e50DF3C689c90Afa79 |
| FluidLockerFactory (Proxy)      | 0xE7e0761ee3251EF9Ae0956b76cf42B4028Be1e8D | https://sepolia.basescan.org/address/0xE7e0761ee3251EF9Ae0956b76cf42B4028Be1e8D |

## Test Coverage :

Current test coverage is as follow :

| File                            | % Lines         | % Statements     | % Branches      | % Funcs         |
| ------------------------------- | --------------- | ---------------- | --------------- | --------------- |
| src/EPProgramManager.sol        | 100.00% (42/42) | 100.00% (56/56)  | 100.00% (14/14) | 100.00% (13/13) |
| src/FluidEPProgramManager.sol   | 98.72% (77/78)  | 98.99% (98/99)   | 100.00% (20/20) | 92.86% (13/14)  |
| src/FluidLocker.sol             | 100.00% (80/80) | 98.06% (101/103) | 86.67% (13/15)  | 100.00% (22/22) |
| src/FluidLockerFactory.sol      | 85.00% (17/20)  | 80.95% (17/21)   | 0.00% (0/2)     | 81.82% (9/11)   |
| src/Fontaine.sol                | 100.00% (20/20) | 95.83% (23/24)   | 75.00% (3/4)    | 100.00% (3/3)   |
| src/StakingRewardController.sol | 93.75% (15/16)  | 94.44% (17/18)   | 100.00% (3/3)   | 87.50% (7/8)    |

## Deployment Procedure

### Step 1 - ETH Mainnet Token Deployment

```shell
OWNER={DEPLOYER_ADDRESS} \
INITIAL_SUPPLY=1000000000000000000000000000 \
forge script script/DeployFluidToken.s.sol:DeployL1FluidToken --ffi --rpc-url {ETH_MAINNET_RPC_URL} --broadcast -vvv
```

### Step 2 - Transfer 650M $FLUID to Foundation Multisig (L1)

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
