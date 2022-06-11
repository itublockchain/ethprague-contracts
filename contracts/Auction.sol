// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

contract Auction {
    struct AuctionDetails{
        bool active,
        uint nftId,
        address nftAddress,
        address nftOwner,
        uint reservePrice,
        uint highestBid,
        address leadAddress,
        uint deadline
    }

    address owner;
    address manager;
    mapping(address => mapping(uint => AuctionDetails)) public  auctionDetails;

    constructor(address managerAddress) {
        owner = msg.sender;
        manager = managerAddress;
    }

    function addBid(address _nftAddress, uint _nftId, uint _bidAmount) public {
        require(auctionDetails[_nftAddress][_nftId].active == true, "Auction is not active");
        require(_bidAmount > auctionDetails[_nftAddress][_nftId].reservePrice, "Reserve price is not met");
        require(block.timestamp < auctionDetails[_nftAddress][_nftId].deadline, "Auction expired");
        require(auctionDetails[_nftAddress][_nftId].highestBid < _bidAmount, "Bid lower than last bid");
        auctionDetails[_nftAddress][_nftId].highestBid = _bidAmount;
        auctionDetails[_nftAddress][_nftId].leadAddress = msg.sender;
    }
    

    function claimNft() external{}


    function putOnAuction(address fromAddress, address nftAddress, address nftOwner, uint nftId, uint reservePrice, uint deadline) public {
        require(block.timestamp < deadline, "Invalid deadline");
        auctionDetails[nftAddress][nftId] = AuctionDetails(
            true,
            nftId,
            nftAddress,
            nftOwner,
            reserveprice,
            highestBid,
            nftOwner,
            deadline
        );
    }

    function stopAuction(address fromAddress, address nftAddress, uint nftId) public {
        require(manager == msg.sender, "Caller is not manager");
        require(auctionDetails[nftAddress][tokenId].active == false, "Auction is not active");

        delete auctionDetails[nftAddress][tokenId];
    }


}