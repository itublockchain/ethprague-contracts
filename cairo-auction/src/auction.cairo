# SPDX-License-Identifier: MIT

%lang starknet

from lib.cairo_contracts.src.openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from starkware.starknet.common.eth_utils import assert_valid_eth_address
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_lt
from starkware.cairo.common.bool import TRUE
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.messages import send_message_to_l1
from starkware.starknet.common.syscalls import (
  get_block_timestamp, get_caller_address
)

## CONSTANTS & TYPES
################################################################################

# keccak256("claim_nft")[:4] = 0x12941492 = 311694482
const MESSAGE_CLAIM_NFT=311694482

# Address of ETH token
const ETH=2087021424722619777119509474943472645767659996348769578120564519014510906823

struct AuctionDetails:
  member active: felt
  member nft_id: felt
  member nft_addr: felt
  member nft_owner: felt
  member reserve_price: felt
  member highest_bid: felt
  member lead_addr: felt
  member deadline: felt
end

## STORAGE
################################################################################

@storage_var
func owner() -> (owner_addr: felt):
end

@storage_var
func manager() -> (manager_addr: felt):
end

@storage_var
func auction_details(nft_addr: felt, nft_id: felt) -> (details: AuctionDetails):
end

## CONSTRUCTOR
################################################################################

@constructor
func constructor{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(manager_addr: felt):
  let (caller: felt) = get_caller_address()

  owner.write(caller)
  manager.write(manager_addr)
  return()
end

## VIEWS 
################################################################################

@view
func get_auction_details{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(nft_addr: felt, nft_id: felt) -> (details: AuctionDetails):
 return auction_details.read(nft_addr, nft_id)
end

## EXTERNALS
################################################################################

@external
func add_bid{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(nft_addr: felt, nft_id: felt, bid_amt: felt):
  let (auction: AuctionDetails) = auction_details.read(nft_addr, nft_id)
  let (timestamp: felt) = get_block_timestamp()
  let (caller: felt) = get_caller_address()

  with_attr error_message("Auction is not active"):
    assert auction.active = TRUE
  end

  with_attr error_message("Reserve price is not met"):
    assert_lt(bid_amt, auction.reserve_price)
  end

  with_attr error_message("Auction expired"):
    assert_lt(timestamp, auction.deadline)
  end

  with_attr error_message("Bid is lte than the last bid"):
    assert_lt(auction.highest_bid, bid_amt)
  end

  # Update auction details
  auction_details.write(
    nft_addr=nft_addr,
    nft_id=nft_id,
    value=AuctionDetails(
      active=TRUE,
      nft_id=auction.nft_id,
      nft_addr=auction.nft_addr,
      nft_owner=auction.nft_owner,
      reserve_price=auction.reserve_price,
      highest_bid=bid_amt,
      lead_addr=caller,
      deadline=auction.deadline
    ))
  return ()
end

@external
func claim_nft{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(nft_addr: felt, nft_id: felt, l1_claimer: felt):
  let (caller: felt) = get_caller_address()
  let (timestamp: felt) = get_block_timestamp()
  let (auction: AuctionDetails) = auction_details.read(nft_addr, nft_id)

  with_attr error_message("Auction is not active"):
    assert auction.active = TRUE
  end

  with_attr error_message("Auction is not finished"):
    assert_lt(auction.deadline, timestamp)
  end

  with_attr error_message("Not winning address"):
    assert auction.lead_addr = caller
  end

  with_attr error_message("L1 claimer is invalid"):
    assert_valid_eth_address(l1_claimer)
  end

  # Try to make payment to the owner
  IERC20.transferFrom(
    contract_address=ETH,
    sender=caller,
    recipient=auction.nft_owner,
    amount=Uint256(auction.highest_bid, 0) 
  )

  # Make the call to the L1 contract
  let (manager_address: felt) = manager.read()
  let (message_payload: felt*) = alloc()
  assert message_payload[0] = MESSAGE_CLAIM_NFT
  assert message_payload[1] = auction.nft_addr
  assert message_payload[2] = auction.nft_id
  assert message_payload[3] = l1_claimer

  send_message_to_l1(
    to_address=manager_address,
    payload_size=4,
    payload=message_payload)

  _delete_auction(nft_addr, nft_id)
  return ()
end

## L1 HANDLERS
################################################################################

@l1_handler
func put_on_auction{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(
  from_address: felt, 
  nft_addr: felt, 
  nft_owner: felt,
  nft_id: felt, 
  reserve_price: felt, 
  deadline: felt
):
  let (auction: AuctionDetails) = auction_details.read(nft_addr, nft_id)
  let (caller: felt) = get_caller_address()
  let (timestamp: felt) = get_block_timestamp()

  with_attr error_message("Invalid owner address"):
    assert_valid_eth_address(nft_owner)
  end

  with_attr error_message("Invalid NFT contract"):
    assert_valid_eth_address(nft_addr)
  end

  with_attr error_message("Caller is not manager"):
    let (manager_addr: felt) = manager.read()
    assert manager_addr = caller 
  end

  with_attr error_message("Invalid deadline"):
    assert_lt(timestamp, deadline)
  end

  auction_details.write(
    nft_addr=nft_addr,
    nft_id=nft_id,
    value=AuctionDetails(
      active=TRUE,
      nft_id=nft_id,
      nft_addr=nft_addr,
      nft_owner=nft_owner,
      reserve_price=reserve_price,
      highest_bid=0,
      lead_addr=nft_owner,
      deadline=deadline))
  return ()
end

@l1_handler
func stop_auction{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(
  from_address: felt,
  nft_addr: felt,
  nft_id: felt
):
  let (auction: AuctionDetails) = auction_details.read(nft_addr, nft_id)
  let (caller: felt) = get_caller_address()

  with_attr error_message("Invalid NFT contract"):
    assert_valid_eth_address(nft_addr)
  end

  with_attr error_message("Caller is not manager"):
    let (manager_addr: felt) = manager.read()
    assert manager_addr = caller
  end

  with_attr error_message("Auction is not active"):
    assert auction.active = TRUE
  end

  _delete_auction(nft_addr, nft_id)
  # todo: emit event
  return()
end

## HELPERS
################################################################################

func _delete_auction{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr  
}(nft_addr: felt, nft_id: felt):
  auction_details.write(
    nft_addr=nft_addr,
    nft_id=nft_id,
    value=AuctionDetails(0,0,0,0,0,0,0,0)
  )
  return()
end