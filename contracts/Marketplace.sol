// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./interfaces/IStarknetCore.sol";

contract Marketplace is ERC721Holder {

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct AuctionListing {
        address seller;
        uint256 startingPrice;
        uint256 duration;
    }

    struct BuyNowListing {
        address seller;
        uint256 price;
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    //NFT contract address => tokenId => Auctionlisting
    mapping(address => mapping(uint256 => AuctionListing)) auctionListings;
    mapping(address => mapping(uint256 => BuyNowListing)) buyNowListings;

    IStarknetCore immutable starknetCore;
    
    uint256 constant INITIALIZE_SELECTOR =
    215307247182100370520050591091822763712463273430149262739280891880522753123;

    uint256 constant STOP_SELECTOR =
    215307247182100370520050591091822763712463273430149262739280891880522753124;
    
    uint256 constant L2CONTRACT_ADDRESS =
    215307247182100370520050591091822763712463273430149262739280891880522753123;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AuctionListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 startingPrice,
        uint256 endTime
    );
    
    event AuctionUnlisted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
    
    event NFTListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event NFTUnlisted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _starknetCoreAddress) {
        starknetCore = IStarknetCore(_starknetCoreAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function putOnAuction(address nftAddress, uint tokenId, uint startingPrice, uint duration) external {

        IERC721(nftAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        auctionListings[nftAddress][tokenId] = AuctionListing(msg.sender, startingPrice, block.timestamp + duration);

        //[nftAddress, tokenId, startingPrice, endTime]
        uint256[] memory payload = new uint256[](4);
        payload[0] = uint256(uint160(nftAddress));
        payload[1] = tokenId;
        payload[2] = startingPrice;
        payload[3] = block.timestamp + duration;
        
        starknetCore.sendMessageToL2(
            L2CONTRACT_ADDRESS, 
            INITIALIZE_SELECTOR,
            payload
            );
        
        emit AuctionListed(msg.sender, nftAddress, tokenId, startingPrice, block.timestamp + duration);
    }

    function putOnBuyNow(address nftAddress, uint tokenId, uint price) external {
        IERC721(nftAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        buyNowListings[nftAddress][tokenId] = BuyNowListing(msg.sender, price);
        emit NFTListed(msg.sender, nftAddress, tokenId, price);
    }

    function buyNow(address nftAddress, uint tokenId) external payable {
        require(buyNowListings[nftAddress][tokenId].price == msg.value);
        delete buyNowListings[nftAddress][tokenId];
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        payable(buyNowListings[nftAddress][tokenId].seller).transfer(msg.value);
        emit NFTUnlisted(msg.sender, nftAddress, tokenId, msg.value);
    }

    function removeFromAuction(address nftAddress, uint tokenId) external {
        require(auctionListings[nftAddress][tokenId].seller == msg.sender);
        delete auctionListings[nftAddress][tokenId];
        
        //[nftAddress, tokenId]
        uint256[] memory payload = new uint256[](2);
        payload[0] = uint256(uint160(nftAddress));
        payload[1] = tokenId;
        
        starknetCore.sendMessageToL2(
            L2CONTRACT_ADDRESS,
            STOP_SELECTOR,
            payload
            );
        
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        emit AuctionUnlisted(msg.sender, nftAddress, tokenId);
    }

    function removeFromBuyNow(address nftAddress, uint tokenId) external {
        require(buyNowListings[nftAddress][tokenId].seller == msg.sender);
        delete buyNowListings[nftAddress][tokenId];
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        emit AuctionUnlisted(msg.sender, nftAddress, tokenId);
    }

    function claimAsset(address nftAddress, uint256 tokenId) external {
        uint256[] memory rcvPayload = new uint256[](3);
        rcvPayload[0] = uint256(uint160(msg.sender));
        rcvPayload[1] = uint256(uint160(nftAddress));
        rcvPayload[2] = tokenId;
        
        starknetCore.consumeMessageFromL2(L2CONTRACT_ADDRESS, rcvPayload);

        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenId);
    }

}