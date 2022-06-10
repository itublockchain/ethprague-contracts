// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "./IStarknetCore.sol";

contract Marketplace is ERC721Holder {

    function startSale() external {}

    function revertSale() external {}

    function claimAsset() external {}

}