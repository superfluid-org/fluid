## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract            | Address                                    | Explorer                                                                        |
| ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken          | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| EPProgramManager    | 0xa7D3fbeF15fB211aF404DCc0eF410aCBBd6B6bA2 | https://sepolia.basescan.org/address/0xa7D3fbeF15fB211aF404DCc0eF410aCBBd6B6bA2 |
| PenaltyManager      | 0xe1F66A06c08911203e093303Eb9Ff07EdbFFe030 | https://sepolia.basescan.org/address/0xe1F66A06c08911203e093303Eb9Ff07EdbFFe030 |
| FluidLocker (Logic) | 0xCdb6870aDA52fb5c4D3031376Cfd69F33B87ea37 | https://sepolia.basescan.org/address/0xCdb6870aDA52fb5c4D3031376Cfd69F33B87ea37 |
| Fontaine (Logic)    | 0x0A75Ea9244E60c9C517c24A1723d08610BE9F3a7 | https://sepolia.basescan.org/address/0x0A75Ea9244E60c9C517c24A1723d08610BE9F3a7 |
| FluidLockerFactory  | 0x5E6ebcDE90Fd5e1CaC46BEd9a2C29756A1fFD08D | https://sepolia.basescan.org/address/0x5E6ebcDE90Fd5e1CaC46BEd9a2C29756A1fFD08D |

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
