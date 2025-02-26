import { BigInt } from "@graphprotocol/graph-ts";
import { FluidStreamClaimEvent, ClaimEventUnit } from "../generated/schema";
import {
  FluidStreamClaimed as FluidStreamClaimedEvent,
  FluidStreamsClaimed as FluidStreamsClaimedEvent,
} from "../generated/templates/FluidLocker/FluidLocker";

export function handleFluidStreamClaimed(event: FluidStreamClaimedEvent): void {
  const streamClaimEvent = new FluidStreamClaimEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  streamClaimEvent.locker = event.address;
  streamClaimEvent.claimer = event.transaction.from;
  streamClaimEvent.blockNumber = event.block.number;
  streamClaimEvent.blockTimestamp = event.block.timestamp;
  streamClaimEvent.transactionHash = event.transaction.hash;

  streamClaimEvent.save();

  let claimUnit = new ClaimEventUnit(event.transaction.hash.concatI32(event.logIndex.toI32()));
  claimUnit.event = streamClaimEvent.id;
  claimUnit.programId = event.params.programId.toString();
  claimUnit.amount = event.params.totalProgramUnits;
  claimUnit.save();
}

export function handleFluidStreamClaimedBulk(event: FluidStreamsClaimedEvent): void {
  const streamClaimEvent = new FluidStreamClaimEvent(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  streamClaimEvent.locker = event.address;
  streamClaimEvent.claimer = event.transaction.from;
  streamClaimEvent.blockNumber = event.block.number;
  streamClaimEvent.blockTimestamp = event.block.timestamp;
  streamClaimEvent.transactionHash = event.transaction.hash;

  streamClaimEvent.save();

  for (let i = 0; i < event.params.programIds.length; i++) {
    let claimUnit = new ClaimEventUnit(
      event.transaction.hash.concatI32(event.logIndex.toI32()).concatI32(i)
    );
    claimUnit.event = streamClaimEvent.id;
    claimUnit.programId = event.params.programIds[i].toString();
    claimUnit.amount = BigInt.fromU32(event.params.totalProgramUnits[i]);
    claimUnit.save();
  }
}
