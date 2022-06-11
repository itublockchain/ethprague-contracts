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

@storage_var
func manager() -> (manager_addr: felt):
end

@storage_var
func nonce() -> (nonce: felt):
end

@storage_var
func bids(account: felt, auction_id: felt) -> (amt: felt):
end

@storage_var
func auction_details(auction_id: felt) -> (details: AuctionDetails):
end

@constructor
func constructor{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(manager_addr: felt):
  
  manager.write(manager_addr)
  return()
end

@view
func get_auction_details{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(auction_id: felt) -> (details: AuctionDetails):
 return auction_details.read(auction_id)
end

@view
func get_bid{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(account: felt, auction_id: felt) -> (amt: felt):
  return bids.read(account, auction_id)
end

@external
func add_bid{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(auction_id: felt, bid_amt: felt):
  let (auction: AuctionDetails) = auction_details.read(auction_id)
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
    auction_id=auction_id, 
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
}(auction_id: felt, claimer: felt):
  let (caller: felt) = get_caller_address()
  let (timestamp: felt) = get_block_timestamp()
  let (auction: AuctionDetails) = auction_details.read(auction_id)

  with_attr error_message("Auction is not active"):
    assert auction.active = TRUE
  end

  with_attr error_message("Auction is not finished"):
    assert_lt(auction.deadline, timestamp)
  end

  with_attr error_message("Not winning address"):
    assert auction.lead_addr = caller
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
  assert message_payload[3] = caller

  send_message_to_l1(
    to_address=manager_address,
    payload_size=4,
    payload=message_payload)

  return ()
end

# 1523363669770796724904282918361620777908202468599035418579302836818670410372
@l1_handler
func deposit_nft{
  syscall_ptr: felt*,
  pedersen_ptr: HashBuiltin*,
  range_check_ptr
}(
  from_address: felt, 
  nft_address: felt, 
  nft_owner: felt,
  nft_id: felt, 
  reserve_price: felt, 
  deadline: felt
):
  let (caller: felt) = get_caller_address()
  let (timestamp: felt) = get_block_timestamp()

  with_attr error_message("Invalid owner address"):
    assert_valid_eth_address(nft_owner)
  end

  with_attr error_message("Invalid NFT contract"):
    assert_valid_eth_address(nft_address)
  end

  with_attr error_message("Caller is not manager"):
    let (manager_addr: felt) = manager.read()
    assert manager_addr = caller 
  end

  with_attr error_message("Invalid deadline"):
    assert_lt(timestamp, deadline)
  end

  let (auction_id: felt) = nonce.read()

  auction_details.write(
    auction_id=auction_id,
    value=AuctionDetails(
      active=TRUE,
      nft_id=nft_id,
      nft_addr=nft_address,
      nft_owner=nft_owner,
      reserve_price=reserve_price,
      highest_bid=0,
      lead_addr=nft_owner,
      deadline=deadline))

  nonce.write(value=auction_id + 1)
  return ()
end


# todo: receive nft, set reserve + deadline and start auction
# todo: add bid
# todo: claim and send to eth 
