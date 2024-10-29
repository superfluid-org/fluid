## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract            | Address                                    | Explorer                                                                        |
| ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken          | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| EPProgramManager    | 0x613D7905f7a0cc3D4df20d59b7519Ce0E12605dc | https://sepolia.basescan.org/address/0x613D7905f7a0cc3D4df20d59b7519Ce0E12605dc |
| PenaltyManager      | 0xE889125DA203af3776EB4ADe8965Cb3200E61728 | https://sepolia.basescan.org/address/0xE889125DA203af3776EB4ADe8965Cb3200E61728 |
| FluidLocker (Logic) | 0xfA0526CF0FA3bfAF60f6004012c6a8696FEA77Cd | https://sepolia.basescan.org/address/0xfA0526CF0FA3bfAF60f6004012c6a8696FEA77Cd |
| Fontaine (Logic)    | 0x63985bcAc9FA80E5aE62dAd33566895BdE94c508 | https://sepolia.basescan.org/address/0x63985bcAc9FA80E5aE62dAd33566895BdE94c508 |
| FluidLockerFactory  | 0x748aD9cAd05B66b821e6e745646d42afC7642568 | https://sepolia.basescan.org/address/0x748aD9cAd05B66b821e6e745646d42afC7642568 |

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

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
