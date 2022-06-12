// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { Base64 } from "./libraries/Base64.sol";

contract CarbonCounter is ERC721URIStorage, Ownable {
    
    error Soulbound();

    uint totalSupply = 0;

    //svg design will be better, but this is a placeholder for now. we didnt have enough time to design a great svg.
    string constant SVGPart1 = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512"><path d="M283.429 512v-109.714h137.143l-109.714 -118.857h109.714l-116.37 -109.714H402.286L256 36.571 109.714 173.714h109.714l-128 109.714h109.714L91.429 402.286h137.143v109.714z" style="fill:#000;fill-opacity:0.2;stroke:none"/><text class="d" dominant-baseline="front" text-anchor="middle"  x="50%" y="55%" style="font-family:Fantasy;font-size:140px">';
    string constant SVGPart2  = '</text></svg>';
    
    IERC20 immutable carbonToken;

    mapping(address => uint256) ownerToId;
    mapping(address => uint256) burnedCarbons;
    mapping(address => bool) authorized;

    constructor(string memory name, string memory symbol, address carbonAddress) ERC721(name, symbol) {
        carbonToken = IERC20(carbonAddress);
    }

    function mintNFT() external {
        require(balanceOf(msg.sender) == 0, "one token per wallet");
        
        string memory initialSVG = string.concat(SVGPart1, "0", SVGPart2);
        
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"description": "Carbon Offset counter NFT", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(initialSVG)),
                        '"}'
                    )
                )
            )
        );

        string memory initialTokenURI = string(abi.encodePacked("data:application/json;base64,", json));
        
        _safeMint(msg.sender, totalSupply);
        ownerToId[msg.sender] = totalSupply;
        
        _setTokenURI(totalSupply, initialTokenURI);

        unchecked { totalSupply++; }
    }

    function burnCarbonToken() external {
    }

    function increaseCB(address user, uint256 amount) external {
        require(authorized[msg.sender], "Caller not authorized.");
        burnedCarbons[user] += amount;
        updateURI();
    }

    function setAuthorized(address auth) external onlyOwner {
        authorized[auth] = !authorized[auth];
    }

    function updateURI() private {
        uint carbonBurned = burnedCarbons[msg.sender];
        uint tokenId = ownerToId[msg.sender];

        string memory newSVG = string.concat(SVGPart1, Strings.toString(carbonBurned), SVGPart2);

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"description": "Carbon Offset counter NFT", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(newSVG)),
                        '"}'
                    )
                )
            )
        );

        string memory newTokenURI = string(abi.encodePacked("data:application/json;base64,", json));
        
        _setTokenURI(tokenId, newTokenURI);
    }

    /*//////////////////////////////////////////////////////////////
                            SOULBOUND LOGIC
    //////////////////////////////////////////////////////////////*/

    //Disallowed for preventing gas waste
    function _approve(address to, uint256 tokenId) internal override {
        revert Soulbound();
    }

    //Disallowed for preventing gas waste
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal override {
        revert Soulbound();
    }

    //Only allows transfers if it is minting
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if(from != address(0)) revert Soulbound();
    }
}