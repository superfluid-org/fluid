## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract                        | Address                                    | Explorer                                                                        |
| ------------------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken                      | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| FluidEPProgramManager (Logic)   | 0xb183b05F37027d6A17d1dC0bfbF629dd3ebe6b8C | https://sepolia.basescan.org/address/0xb183b05F37027d6A17d1dC0bfbF629dd3ebe6b8C |
| FluidEPProgramManager (Proxy)   | 0xbDCa01AD2ae01827aEA8B323CE5457F642f9E7e1 | https://sepolia.basescan.org/address/0xbDCa01AD2ae01827aEA8B323CE5457F642f9E7e1 |
| StakingRewardController (Logic) | 0x66EB7fF73Eb504fB0D332bAC7c2CADc16Acc1A15 | https://sepolia.basescan.org/address/0x66EB7fF73Eb504fB0D332bAC7c2CADc16Acc1A15 |
| StakingRewardController (Proxy) | 0xef72D3cE2E917F721476966FF34880fB2A560644 | https://sepolia.basescan.org/address/0xef72D3cE2E917F721476966FF34880fB2A560644 |
| FluidLocker (Logic)             | 0xb32D0Fe9E86607D6d81afe93A08406234AfB8cF3 | https://sepolia.basescan.org/address/0xb32D0Fe9E86607D6d81afe93A08406234AfB8cF3 |
| FluidLocker (Beacon)            | 0xd1ac1cFb3c52c3D36886A0abd02c4892910A8919 | https://sepolia.basescan.org/address/0xd1ac1cFb3c52c3D36886A0abd02c4892910A8919 |
| Fontaine (Logic)                | 0x12B8CF66Dc2D350558262be48553CabFe43A784e | https://sepolia.basescan.org/address/0x12B8CF66Dc2D350558262be48553CabFe43A784e |
| Fontaine (Beacon)               | 0xA613A7Ace7f6e5447fcCCAb3dd1e3E969DEE1d31 | https://sepolia.basescan.org/address/0xA613A7Ace7f6e5447fcCCAb3dd1e3E969DEE1d31 |
| FluidLockerFactory (Logic)      | 0x66eCdda65c94D4e84Dc3A55D64215B68c7eF870C | https://sepolia.basescan.org/address/0x66eCdda65c94D4e84Dc3A55D64215B68c7eF870C |
| FluidLockerFactory (Proxy)      | 0x3903e080aC5c2452A8e4adbE17b80C54DF53E8C1 | https://sepolia.basescan.org/address/0x3903e080aC5c2452A8e4adbE17b80C54DF53E8C1 |

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

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

To deploy the contract suite, fill in the `.env` file using `.env.example` as reference.
The sections `Private Keys`, `RPCs`, and `Deployment Settings` must be complete to deploy.

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

```shell
$ forge script script/Deploy.s.sol:DeployScript --ffi --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
```
