## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract              | Address                                    | Explorer                                                                        |
| --------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken            | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| FluidEPProgramManager | 0xe175053257B6A0Fe7EAE537499Ba4465065DdD88 | https://sepolia.basescan.org/address/0xe175053257B6A0Fe7EAE537499Ba4465065DdD88 |
| PenaltyManager        | 0xA6c9DCED06c378a0548D7d4a880e2036A03696CE | https://sepolia.basescan.org/address/0xA6c9DCED06c378a0548D7d4a880e2036A03696CE |
| FluidLocker (Logic)   | 0x783Fcb21077a1b243c915ed639F9c7f5bE9111BB | https://sepolia.basescan.org/address/0x783Fcb21077a1b243c915ed639F9c7f5bE9111BB |
| Fontaine (Logic)      | 0x9a2D08fE4fe75D33990085A436B4aB215Bf9e524 | https://sepolia.basescan.org/address/0x9a2D08fE4fe75D33990085A436B4aB215Bf9e524 |
| FluidLockerFactory    | 0x8DaF7BF1a2052B6BDA0eC46619855Cec77DfbC76 | https://sepolia.basescan.org/address/0x8DaF7BF1a2052B6BDA0eC46619855Cec77DfbC76 |

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
