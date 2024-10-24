## Address Registry :

Latest deployed contract address

### BASE SEPOLIA :

| Contract            | Address                                    | Explorer                                                                        |
| ------------------- | ------------------------------------------ | ------------------------------------------------------------------------------- |
| FluidToken          | 0x3A193aC8FcaCCDa817c174D04081C105154a8441 | https://sepolia.basescan.org/address/0x3A193aC8FcaCCDa817c174D04081C105154a8441 |
| EPProgramManager    | 0x39b890FD826cAED6e56D890398441400f691f340 | https://sepolia.basescan.org/address/0x39b890FD826cAED6e56D890398441400f691f340 |
| PenaltyManager      | 0xC999838C313a58d50a26138D393C6Aa43b6532A0 | https://sepolia.basescan.org/address/0xC999838C313a58d50a26138D393C6Aa43b6532A0 |
| FluidLocker (Logic) | 0xE3078A37BFcDd69394aa1A24ff8b5613C0688efd | https://sepolia.basescan.org/address/0xE3078A37BFcDd69394aa1A24ff8b5613C0688efd |
| Fontaine (Logic)    | 0x15605dD67d8E75DeD4218C3458Ad27EB0e33fF68 | https://sepolia.basescan.org/address/0x15605dD67d8E75DeD4218C3458Ad27EB0e33fF68 |
| FluidLockerFactory  | 0x719a0a7B1acb0863D755484d958ec558a635c785 | https://sepolia.basescan.org/address/0x719a0a7B1acb0863D755484d958ec558a635c785 |

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
