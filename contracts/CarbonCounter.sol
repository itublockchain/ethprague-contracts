// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "./libraries/Base64.sol";

contract CarbonCounter is ERC721URIStorage {
    
    error Soulbound();

    uint totalSupply = 0;

    string constant SVGPart1 = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512"><path d="M283.429 512v-109.714H329.143c92.306 0 129.646 -128 36.571 -164.571 54.747 -36.571 36.571 -128 -36.571 -137.143C329.143 100.571 329.143 36.571 256 36.571S182.857 100.571 182.857 100.571C109.714 109.714 90.002 201.143 146.286 237.714 54.747 274.286 91.319 402.286 182.857 402.286h45.714v109.714z" style="fill:#000;fill-opacity:1;stroke:none"/><text x="50%" y="47%" class="base" fill="url(#c)" dominant-baseline="middle" text-anchor="middle" style="font-family:Josefin Sans,sans-serif;font-size:140px">';
    string constant SVGPart2  = '</text></svg>';
    
    IERC20 immutable carbonToken;

    mapping(address => uint256) ownerToId;
    mapping(address => uint256) burnedCarbons;

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

    function updateURI() internal {
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