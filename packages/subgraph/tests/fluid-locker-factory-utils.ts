import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  GovernorUpdated,
  Initialized,
  LockerCreated,
  Upgraded
} from "../generated/FluidLockerFactory/FluidLockerFactory"

export function createGovernorUpdatedEvent(
  newGovernor: Address
): GovernorUpdated {
  let governorUpdatedEvent = changetype<GovernorUpdated>(newMockEvent())

  governorUpdatedEvent.parameters = new Array()

  governorUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newGovernor",
      ethereum.Value.fromAddress(newGovernor)
    )
  )

  return governorUpdatedEvent
}

export function createInitializedEvent(version: BigInt): Initialized {
  let initializedEvent = changetype<Initialized>(newMockEvent())

  initializedEvent.parameters = new Array()

  initializedEvent.parameters.push(
    new ethereum.EventParam(
      "version",
      ethereum.Value.fromUnsignedBigInt(version)
    )
  )

  return initializedEvent
}

export function createLockerCreatedEvent(
  lockerOwner: Address,
  lockerAddress: Address
): LockerCreated {
  let lockerCreatedEvent = changetype<LockerCreated>(newMockEvent())

  lockerCreatedEvent.parameters = new Array()

  lockerCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "lockerOwner",
      ethereum.Value.fromAddress(lockerOwner)
    )
  )
  lockerCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "lockerAddress",
      ethereum.Value.fromAddress(lockerAddress)
    )
  )

  return lockerCreatedEvent
}

export function createUpgradedEvent(implementation: Address): Upgraded {
  let upgradedEvent = changetype<Upgraded>(newMockEvent())

  upgradedEvent.parameters = new Array()

  upgradedEvent.parameters.push(
    new ethereum.EventParam(
      "implementation",
      ethereum.Value.fromAddress(implementation)
    )
  )

  return upgradedEvent
}
