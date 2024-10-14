## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract            | Address                                    | Explorer                                                                        |
| ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken          | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| EPProgramManager    | 0x7cEC6490CEfF2768A1ecfc6d71C1dF819A8a6E3c | https://sepolia.basescan.org/address/0x7cEC6490CEfF2768A1ecfc6d71C1dF819A8a6E3c |
| PenaltyManager      | 0x4fEc5B896AF3AFFeE74fC6F25c476fF53aAEfCe1 | https://sepolia.basescan.org/address/0x4fEc5B896AF3AFFeE74fC6F25c476fF53aAEfCe1 |
| FluidLocker (Logic) | 0x45009fB03ebB58f759E43BB01318a50f8C2f3f8b | https://sepolia.basescan.org/address/0x45009fB03ebB58f759E43BB01318a50f8C2f3f8b |
| Fontaine (Logic)    | 0x50De94359BdCAE78674e6918519DF0220aEfD514 | https://sepolia.basescan.org/address/0x50De94359BdCAE78674e6918519DF0220aEfD514 |
| FluidLockerFactory  | 0x6bC1063D8A1D9Aa10438d937A233c2F953d40cC3 | https://sepolia.basescan.org/address/0x6bC1063D8A1D9Aa10438d937A233c2F953d40cC3 |

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
