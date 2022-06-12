// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStarknetCore.sol";

/// @author Viridis Finance Team
/// @title Marketplace that can communicate with Starknet in NFT auctions

contract Marketplace is ERC721Holder, Ownable {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    // Information about the NFT being auctioned
    struct AuctionListing {
        address seller; // Seller
        uint256 startingPrice; // The minimum value at which the auction will start
        uint256 duration; // The time the auction will continue
    }

    // Information about the NFT put up for sale directly
    struct BuyNowListing {
        address seller; // Seller
        uint256 price; // Price at which NFT will be sold
    }

    /*//////////////////////////////////////////////////////////////
                             STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // Auction informations - (NFT Address => (TokenId => AuctionListing))
    mapping(address => mapping(uint256 => AuctionListing))
        public auctionListings;

    // Direct sales informations - (NFT Address => (TokenId => BuyNowListings))
    mapping(address => mapping(uint256 => BuyNowListing)) public buyNowListings;

    // The address where the share to be received when the auction ends
    address payable public pool;

    // Starknet core contract that allows us to communicate with Starknet
    IStarknetCore immutable starknetCore;

    // The selector that allows us to start the auction on Starknet
    uint256 constant INITIALIZE_SELECTOR =
        1611874740453389057402018505070086259979648973895522495658169458461190851914;

    // The selector that allows us to stop the auction on Starknet
    uint256 constant STOP_SELECTOR =
        32032038621086203069106091894612339762081205489210192790601047421080225239;

    // Starknet auction address
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

    /**
     * @notice Constructor function - takes the parameters of the Starknet Core and tresuary address
     * @param _starknetCoreAddress address - Starknet core contract
     * @param _poolAddress address - Pool
     */

    constructor(address _starknetCoreAddress, address _poolAddress) {
        starknetCore = IStarknetCore(_starknetCoreAddress);
        pool = payable(_poolAddress);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Putting the NFT up for auction
     * @param nftAddress uint256 - contract address of NFT
     * @param tokenId uint256 - id of NFT
     * @param startingPrice uint256 - minimum price of NFT
     * @param duration uint - auction duration of NFT
     */

    function putOnAuction(
        address nftAddress,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration
    ) external {
        IERC721(nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        auctionListings[nftAddress][tokenId] = AuctionListing(
            msg.sender,
            startingPrice,
            block.timestamp + duration
        );

        //[nftAddress, tokenId, startingPrice, endTime]
        uint256[] memory payload = new uint256[](4);
        payload[0] = uint256(uint160(nftAddress));
        payload[1] = tokenId;
        payload[2] = startingPrice;
        payload[3] = block.timestamp + duration;

        // sending message to Starknet
        starknetCore.sendMessageToL2(
            L2CONTRACT_ADDRESS,
            INITIALIZE_SELECTOR,
            payload
        );

        emit AuctionListed(
            msg.sender,
            nftAddress,
            tokenId,
            startingPrice,
            block.timestamp + duration
        );
    }

    /**
     * @notice Putting the NFT up for direct sale
     * @param nftAddress uint256 - contract address of NFT
     * @param tokenId uint256 - id of NFT
     * @param price uint256 - price of NFT
     */

    function putOnBuyNow(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external {
        IERC721(nftAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        buyNowListings[nftAddress][tokenId] = BuyNowListing(msg.sender, price);
        emit NFTListed(msg.sender, nftAddress, tokenId, price);
    }

    /**
     * @notice Buying NFT
     * @param nftAddress uint256 - contract address of NFT
     * @param tokenId uint256 - id of NFT
     */
    function buyNow(address nftAddress, uint256 tokenId) external payable {
        require(buyNowListings[nftAddress][tokenId].price == msg.value);
        delete buyNowListings[nftAddress][tokenId];
        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        payable(buyNowListings[nftAddress][tokenId].seller).transfer(msg.value);
        emit NFTUnlisted(msg.sender, nftAddress, tokenId, msg.value);
    }

    /**
     * @notice Removing the NFT up for auction
     * @param nftAddress uint256 - contract address of NFT
     * @param tokenId uint256 - id of NFT
     */

    function removeFromAuction(address nftAddress, uint256 tokenId) external {
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

        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        emit AuctionUnlisted(msg.sender, nftAddress, tokenId);
    }

    /**
     * @notice Removing NFT from direct sale
     * @param nftAddress uint256 - contract address of NFT
     * @param tokenId uint256 - id of NFT
     */
    function removeFromBuyNow(address nftAddress, uint256 tokenId) external {
        require(buyNowListings[nftAddress][tokenId].seller == msg.sender);
        delete buyNowListings[nftAddress][tokenId];
        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        emit AuctionUnlisted(msg.sender, nftAddress, tokenId);
    }

    /**
     * @notice This function reads the result in Starknet and allows the winner to claim NFT.
     * @param nftAddress uint256 - contract address of NFT
     * @param tokenId uint256 - id of NFT
     */
    function claimAsset(address nftAddress, uint256 tokenId) external payable {
        uint256[] memory rcvPayload = new uint256[](4);
        rcvPayload[0] = uint256(uint160(msg.sender));
        rcvPayload[1] = uint256(uint160(nftAddress));
        rcvPayload[2] = tokenId;
        rcvPayload[3] = msg.value;

        starknetCore.consumeMessageFromL2(L2CONTRACT_ADDRESS, rcvPayload);

        address payable seller = payable(
            auctionListings[nftAddress][tokenId].seller
        );
        uint256 sellerShare = (msg.value * 98) / 100;

        delete auctionListings[nftAddress][tokenId];

        IERC721(nftAddress).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );

        seller.transfer(sellerShare);
    }

    /**
     * @notice Changing L2 contract address
     * @param _L2Address address - new Starknet contract address
     */
    function setL2Address(uint256 _L2Address) external onlyOwner {
        L2CONTRACT_ADDRESS = _L2Address;
    }
}
