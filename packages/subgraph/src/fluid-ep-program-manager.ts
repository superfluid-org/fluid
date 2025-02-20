import { BigInt } from "@graphprotocol/graph-ts";
import {
  ProgramCancelled as ProgramCancelledEvent,
  ProgramCreated as ProgramCreatedEvent,
  ProgramFunded as ProgramFundedEvent,
  ProgramSignerUpdated as ProgramSignerUpdatedEvent,
  ProgramStopped as ProgramStoppedEvent,
} from "../generated/FluidEPProgramManager/FluidEPProgramManager";
import { Program } from "../generated/schema";

export function handleProgramCreated(event: ProgramCreatedEvent): void {
  let program = getOrCreateProgram(event.params.programId.toString());

  program.programAdmin = event.params.programAdmin;
  program.signer = event.params.signer;
  program.token = event.params.token;
  program.distributionPool = event.params.distributionPool;

  program.fundingAmount = new BigInt(0);
  program.subsidyAmount = new BigInt(0);
  program.earlyEndDate = new BigInt(0);
  program.endDate = new BigInt(0);
  program.stoppedDate = new BigInt(0);
  program.fundingCompensationAmount = new BigInt(0);
  program.subsidyCompensationAmount = new BigInt(0);
  program.cancellationDate = new BigInt(0);
  program.returnedDeposit = new BigInt(0);

  program.blockNumber = event.block.number;
  program.blockTimestamp = event.block.timestamp;
  program.transactionHash = event.transaction.hash;

  program.save();
}

export function handleProgramCancelled(event: ProgramCancelledEvent): void {
  let program = getOrCreateProgram(event.params.programId.toString());

  program.returnedDeposit = event.params.returnedDeposit;
  program.cancellationDate = event.block.timestamp;

  program.save();
}

export function handleProgramFunded(event: ProgramFundedEvent): void {
  let program = getOrCreateProgram(event.params.programId.toString());

  program.fundingAmount = event.params.fundingAmount;
  program.subsidyAmount = event.params.subsidyAmount;
  program.earlyEndDate = event.params.earlyEndDate;
  program.endDate = event.params.endDate;

  program.save();
}

export function handleProgramSignerUpdated(
  event: ProgramSignerUpdatedEvent
): void {
  let program = getOrCreateProgram(event.params.programId.toString());

  program.signer = event.params.newSigner;

  program.save();
}

export function handleProgramStopped(event: ProgramStoppedEvent): void {
  let program = getOrCreateProgram(event.params.programId.toString());

  program.fundingCompensationAmount = event.params.fundingCompensationAmount;
  program.subsidyCompensationAmount = event.params.subsidyCompensationAmount;
  program.stoppedDate = event.block.timestamp;

  program.save();
}

function getOrCreateProgram(id: string): Program {
  let program = Program.load(id.toString());
  if (program == null) {
    program = new Program(id.toString());
  }
  return program;
}
