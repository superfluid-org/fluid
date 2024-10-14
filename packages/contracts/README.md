## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract            | Address                                    | Explorer                                                                          |
| ------------------- | ------------------------------------------ | --------------------------------------------------------------------------------- |
| FluidToken          | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://mumbai.polygonscan.com/address/0xc0f123B96d67C2D600b91Fdee740E05D18e4DD45 |
| EPProgramManager    | 0x7cEC6490CEfF2768A1ecfc6d71C1dF819A8a6E3c | https://mumbai.polygonscan.com/address/0xc0f123B96d67C2D600b91Fdee740E05D18e4DD45 |
| PenaltyManager      | 0x4fEc5B896AF3AFFeE74fC6F25c476fF53aAEfCe1 | https://mumbai.polygonscan.com/address/0xB7Ab2197eF273F759C174D553E37633c0E691460 |
| FluidLocker (Logic) | 0x45009fB03ebB58f759E43BB01318a50f8C2f3f8b | https://mumbai.polygonscan.com/address/0x2441290537D452A5e281755fE1126275f27032ff |
| Fontaine (Logic)    | 0x50De94359BdCAE78674e6918519DF0220aEfD514 | https://mumbai.polygonscan.com/address/0x392cfc9F4e839B1C49f422851ed004f2d7B81939 |
| FluidLockerFactory  | 0x6bC1063D8A1D9Aa10438d937A233c2F953d40cC3 | https://mumbai.polygonscan.com/address/0x78cD0E886b6C8EfCf2E67612fa45Ff16f685815d |

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
