import { LockerCreated as LockerCreatedEvent } from "../generated/FluidLockerFactory/FluidLockerFactory";
import { Locker } from "../generated/schema";
import { FluidLocker as FluidLockerTemplate } from "../generated/templates";

export function handleLockerCreated(event: LockerCreatedEvent): void {
  let entity = new Locker(event.params.lockerAddress);
  entity.lockerOwner = event.params.lockerOwner;

  entity.blockNumber = event.block.number;
  entity.blockTimestamp = event.block.timestamp;
  entity.transactionHash = event.transaction.hash;

  entity.save();

  // Note: this is necessary otherwise we will not be able to capture
  // template data source events.
  FluidLockerTemplate.create(event.params.lockerAddress);
}
