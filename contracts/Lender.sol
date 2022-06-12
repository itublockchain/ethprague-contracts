// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
    Non-profit lending protocol using bct Carbon token as collateral, lending fee is taken as a percentage of the collateralized carbon tokens.
    which gets locked in this contract(burned). Burned carbon tokens are carbon emissions offseted in real life.
    this protocol uses its other products as a source of income to fund its matic pool.
*/

contract Lender {

    struct Loan {
        uint256 lendedMatic;
        uint256 borrowedCarbon;
        uint256 endTime;
    }

    IERC20 immutable carbonToken; //base carbon tonne

    mapping(address => Loan) loans; //users can't take new loans before repaying

    uint256 constant oneWeekInterest = 5; //percent
    uint256 constant twoWeekInterest = 10; //percent
    uint256 constant threeWeekInterest = 15; //percent
    uint256 constant fourWeekInterest = 20; //percent

    uint256 constant maticPriceOfCarbon = 4; //will use chainlink price feed once carbon tokens get popular and chainlink starts providing price feeds for them.

    event LoanTaken(
        address borrower,
        uint256 amountLended,
        uint256 amountBorrowed,
        uint256 endTime
    );

    event LoanRepaid(
        address borrower,
        uint256 amountRepaid
    ); 

    constructor(address carbonAddress) {
        carbonToken = IERC20(carbonAddress);
    }

    receive() external payable {}

    function takeLoan(uint256 collateralAmount, uint256 duration) external {
        require(loans[msg.sender].endTime == 0);
        //User must approve this contract before taking a loan
        require(carbonToken.transferFrom(msg.sender, address(this), collateralAmount));

        //Calculate amount of matic to lend
        uint maticLendAmount;

        if (duration == 7 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - oneWeekInterest) / 100;
        } else if (duration == 14 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - twoWeekInterest) / 100;
        } else if (duration == 21 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - threeWeekInterest) / 100;
        } else if (duration == 28 days) {
            maticLendAmount = collateralAmount * maticPriceOfCarbon * (100 - fourWeekInterest) / 100;
        }

        address payable borrower = payable(msg.sender);

        borrower.transfer(maticLendAmount);

        Loan memory loan = Loan(
            maticLendAmount,
            collateralAmount,
            block.timestamp + duration
        );

        loans[msg.sender] = loan;

        emit LoanTaken(msg.sender, maticLendAmount, collateralAmount, block.timestamp + duration);
    }

    function repayLoan() external payable { 
        require(msg.value == loans[msg.sender].lendedMatic); //User sends back the lended matic
        require(block.timestamp <= loans[msg.sender].endTime);  //If user does not pay back in time he/she loses money and he/she can't take a loan ever again.

        //we give back half the interest we took to incentivize repayment of loans, other half is carbon tokens locked in this contract which is equivalent to burning.
        uint256 carbonRepayAmount = (loans[msg.sender].borrowedCarbon + (loans[msg.sender].lendedMatic / maticPriceOfCarbon)) / 2;
        require(carbonToken.transferFrom(address(this), msg.sender, carbonRepayAmount));


        delete loans[msg.sender];

        emit LoanRepaid(msg.sender, carbonRepayAmount);
    }
}