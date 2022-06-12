// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Lender {

    struct Loan {
        uint256 lendedMatic;
        uint256 borrowedCarbon;
        uint256 endTime;
    }

    IERC20 immutable carbonToken;

    mapping(address => Loan) loans;

    uint256 constant oneWeekInterest = 5; //percent
    uint256 constant twoWeekInterest = 10; //percent
    uint256 constant threeWeekInterest = 15; //percent
    uint256 constant fourWeekInterest = 20; //percent

    uint256 constant maticPriceOfCarbon = 4; 

    constructor(address carbonAddress) {
        carbonToken = IERC20(carbonAddress);
    }

    function takeLoan(uint256 collateralAmount, uint256 duration) external {
        require(carbonToken.transferFrom(msg.sender, address(this), collateralAmount));

        uint maticLendAmount;

        address payable borrower = payable(msg.sender);

        if (duration == 7 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - oneWeekInterest) / 100;
        } else if (duration == 14 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - twoWeekInterest) / 100;
        } else if (duration == 21 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - threeWeekInterest) / 100;
        } else if (duration == 28 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - fourWeekInterest) / 100;
        }

        borrower.transfer(maticLendAmount);

        Loan memory loan = Loan(
            maticLendAmount,
            collateralAmount,
            block.timestamp + duration
        );

        loans[msg.sender] = loan;
    }

    function repayLoan() external payable{
        require(msg.value == loans[msg.sender].lendedMatic);
        require(block.timestamp <= loans[msg.sender].endTime);
        
        uint256 carbonRepayAmount = (loans[msg.sender].borrowedCarbon + (loans[msg.sender].lendedMatic / maticPriceOfCarbon)) / 2;
        require(carbonToken.transferFrom(address(this), msg.sender, carbonRepayAmount));


        delete loans[msg.sender];
    }
}