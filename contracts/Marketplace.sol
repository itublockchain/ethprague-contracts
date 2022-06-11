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
    mapping(address => mapping(uint256 => AuctionListing)) public auctionListings;
    mapping(address => mapping(uint256 => BuyNowListing)) public buyNowListings;

    address payable public pool;
    IStarknetCore immutable starknetCore;

    uint256 constant INITIALIZE_SELECTOR =
    1611874740453389057402018505070086259979648973895522495658169458461190851914;

    uint256 constant STOP_SELECTOR =
    32032038621086203069106091894612339762081205489210192790601047421080225239;

    uint256 L2CONTRACT_ADDRESS =
    88716746582861518782029534537239299938153893061365637382342674063266644116;

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

    constructor(address _starknetCoreAddress, address _poolAddress) {
        starknetCore = IStarknetCore(_starknetCoreAddress);
        pool = payable(_poolAddress);
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

    function claimAsset(address nftAddress, uint256 tokenId) external payable {
        uint256[] memory rcvPayload = new uint256[](4);
        rcvPayload[0] = uint256(uint160(msg.sender));
        rcvPayload[1] = uint256(uint160(nftAddress));
        rcvPayload[2] = tokenId;
        rcvPayload[3] = msg.value;

        starknetCore.consumeMessageFromL2(L2CONTRACT_ADDRESS, rcvPayload);

        address payable seller = payable(auctionListings[nftAddress][tokenId].seller);
        uint256 sellerShare = msg.value * 98 / 100;
        
        delete auctionListings[nftAddress][tokenId];        
        
        IERC721(nftAddress).safeTransferFrom(address(this), msg.sender, tokenId);
        
        seller.transfer(sellerShare);
    }

    function setL2Address(uint256 _L2Address) external {
        L2CONTRACT_ADDRESS = _L2Address;
    }

}