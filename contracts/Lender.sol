// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lender {

    struct Loan {
        address borrower;
        uint256 amount;
        uint256 deadline;
    }

    IERC20 immutable carbonToken;

    constructor(address carbonAddress) {
        carbonToken = IERC20(carbonAddress);
    }
}