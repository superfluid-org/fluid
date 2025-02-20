import { newMockEvent } from "matchstick-as"
import { ethereum, BigInt, Address } from "@graphprotocol/graph-ts"
import {
  Initialized,
  OwnershipTransferred,
  ProgramCancelled,
  ProgramCreated,
  ProgramFunded,
  ProgramSignerUpdated,
  ProgramStopped,
  Upgraded,
  UserUnitsUpdated
} from "../generated/FluidEPProgramManager/FluidEPProgramManager"

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

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent =
    changetype<OwnershipTransferred>(newMockEvent())

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createProgramCancelledEvent(
  programId: BigInt,
  returnedDeposit: BigInt
): ProgramCancelled {
  let programCancelledEvent = changetype<ProgramCancelled>(newMockEvent())

  programCancelledEvent.parameters = new Array()

  programCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "programId",
      ethereum.Value.fromUnsignedBigInt(programId)
    )
  )
  programCancelledEvent.parameters.push(
    new ethereum.EventParam(
      "returnedDeposit",
      ethereum.Value.fromUnsignedBigInt(returnedDeposit)
    )
  )

  return programCancelledEvent
}

export function createProgramCreatedEvent(
  programId: BigInt,
  programAdmin: Address,
  signer: Address,
  token: Address,
  distributionPool: Address
): ProgramCreated {
  let programCreatedEvent = changetype<ProgramCreated>(newMockEvent())

  programCreatedEvent.parameters = new Array()

  programCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "programId",
      ethereum.Value.fromUnsignedBigInt(programId)
    )
  )
  programCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "programAdmin",
      ethereum.Value.fromAddress(programAdmin)
    )
  )
  programCreatedEvent.parameters.push(
    new ethereum.EventParam("signer", ethereum.Value.fromAddress(signer))
  )
  programCreatedEvent.parameters.push(
    new ethereum.EventParam("token", ethereum.Value.fromAddress(token))
  )
  programCreatedEvent.parameters.push(
    new ethereum.EventParam(
      "distributionPool",
      ethereum.Value.fromAddress(distributionPool)
    )
  )

  return programCreatedEvent
}

export function createProgramFundedEvent(
  programId: BigInt,
  fundingAmount: BigInt,
  subsidyAmount: BigInt,
  earlyEndDate: BigInt,
  endDate: BigInt
): ProgramFunded {
  let programFundedEvent = changetype<ProgramFunded>(newMockEvent())

  programFundedEvent.parameters = new Array()

  programFundedEvent.parameters.push(
    new ethereum.EventParam(
      "programId",
      ethereum.Value.fromUnsignedBigInt(programId)
    )
  )
  programFundedEvent.parameters.push(
    new ethereum.EventParam(
      "fundingAmount",
      ethereum.Value.fromUnsignedBigInt(fundingAmount)
    )
  )
  programFundedEvent.parameters.push(
    new ethereum.EventParam(
      "subsidyAmount",
      ethereum.Value.fromUnsignedBigInt(subsidyAmount)
    )
  )
  programFundedEvent.parameters.push(
    new ethereum.EventParam(
      "earlyEndDate",
      ethereum.Value.fromUnsignedBigInt(earlyEndDate)
    )
  )
  programFundedEvent.parameters.push(
    new ethereum.EventParam(
      "endDate",
      ethereum.Value.fromUnsignedBigInt(endDate)
    )
  )

  return programFundedEvent
}

export function createProgramSignerUpdatedEvent(
  programId: BigInt,
  newSigner: Address
): ProgramSignerUpdated {
  let programSignerUpdatedEvent =
    changetype<ProgramSignerUpdated>(newMockEvent())

  programSignerUpdatedEvent.parameters = new Array()

  programSignerUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "programId",
      ethereum.Value.fromUnsignedBigInt(programId)
    )
  )
  programSignerUpdatedEvent.parameters.push(
    new ethereum.EventParam("newSigner", ethereum.Value.fromAddress(newSigner))
  )

  return programSignerUpdatedEvent
}

export function createProgramStoppedEvent(
  programId: BigInt,
  fundingCompensationAmount: BigInt,
  subsidyCompensationAmount: BigInt
): ProgramStopped {
  let programStoppedEvent = changetype<ProgramStopped>(newMockEvent())

  programStoppedEvent.parameters = new Array()

  programStoppedEvent.parameters.push(
    new ethereum.EventParam(
      "programId",
      ethereum.Value.fromUnsignedBigInt(programId)
    )
  )
  programStoppedEvent.parameters.push(
    new ethereum.EventParam(
      "fundingCompensationAmount",
      ethereum.Value.fromUnsignedBigInt(fundingCompensationAmount)
    )
  )
  programStoppedEvent.parameters.push(
    new ethereum.EventParam(
      "subsidyCompensationAmount",
      ethereum.Value.fromUnsignedBigInt(subsidyCompensationAmount)
    )
  )

  return programStoppedEvent
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

export function createUserUnitsUpdatedEvent(
  user: Address,
  programId: BigInt,
  newUnits: BigInt
): UserUnitsUpdated {
  let userUnitsUpdatedEvent = changetype<UserUnitsUpdated>(newMockEvent())

  userUnitsUpdatedEvent.parameters = new Array()

  userUnitsUpdatedEvent.parameters.push(
    new ethereum.EventParam("user", ethereum.Value.fromAddress(user))
  )
  userUnitsUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "programId",
      ethereum.Value.fromUnsignedBigInt(programId)
    )
  )
  userUnitsUpdatedEvent.parameters.push(
    new ethereum.EventParam(
      "newUnits",
      ethereum.Value.fromUnsignedBigInt(newUnits)
    )
  )

  return userUnitsUpdatedEvent
}
