## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract            | Address                                    | Explorer                                                                        |
| ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken          | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| EPProgramManager    | 0x376120A6c56c5CA10a9b5eC8F7aFBC2d576f2C35 | https://sepolia.basescan.org/address/0x376120A6c56c5CA10a9b5eC8F7aFBC2d576f2C35 |
| PenaltyManager      | 0x52b0852A204515856387aaf3d6f21b77E66e03a8 | https://sepolia.basescan.org/address/0x52b0852A204515856387aaf3d6f21b77E66e03a8 |
| FluidLocker (Logic) | 0xd1094dD59ca5cBF53Fc89DBce4Eb3F25f148Ed6A | https://sepolia.basescan.org/address/0xd1094dD59ca5cBF53Fc89DBce4Eb3F25f148Ed6A |
| Fontaine (Logic)    | 0x7De77d385828cA2329B05114b9DdAdB824Af1742 | https://sepolia.basescan.org/address/0x7De77d385828cA2329B05114b9DdAdB824Af1742 |
| FluidLockerFactory  | 0xeFE0b1044c26b8050F94A73B7213394D2E0aa504 | https://sepolia.basescan.org/address/0xeFE0b1044c26b8050F94A73B7213394D2E0aa504 |

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
