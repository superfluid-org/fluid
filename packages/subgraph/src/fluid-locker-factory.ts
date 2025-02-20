import { LockerCreated as LockerCreatedEvent } from "../generated/FluidLockerFactory/FluidLockerFactory";
import { LockerCreated } from "../generated/schema";

export function handleLockerCreated(event: LockerCreatedEvent): void {
  let entity = new LockerCreated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  );
  entity.lockerOwner = event.params.lockerOwner;
  entity.lockerAddress = event.params.lockerAddress;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();
}
