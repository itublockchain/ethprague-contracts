// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./interfaces/IUniswapV2Router01.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./CarbonCounter.sol";

contract DonateOnDEX {
    using SafeERC20 for IERC20;

    CarbonCounter carbon;
    address payable public pool;

    constructor(address poolAddress, address nftAddress) {
        pool = payable(poolAddress);
        carbon = CarbonCounter(nftAddress);
    }

    fallback() external payable{}
    receive() external payable{}

    function getAmountsOut(
        address router,
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        return IUniswapV2Router01(router).getAmountsOut(amountIn, path);
    }

    function getAmountsIn(
        address router,
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts) {
        return IUniswapV2Router01(router).getAmountsIn(amountOut, path);
    }

    function swapExactETHForTokens(
        address router,
        uint256 percent, // over 10000
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(msg.value > 0, "No msg.value!");
        require(10000 > percent, "Invalid percent.");

        uint256 donation = (msg.value * percent) / 10000;
        amountOutMin = (amountOutMin * (10000 - percent)) / 10000;

        amounts = IUniswapV2Router01(router).swapExactETHForTokens{
            value: msg.value - donation
        }(amountOutMin, path, msg.sender, deadline);

        pool.transfer(donation);
        carbon.increaseCB(msg.sender, donation);
        
        return amounts;
    }

    function swapTokensForExactETH(
        address router,
        uint256 percent, // over 10000
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(10000 > percent, "Invalid percent.");

        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            amountInMax
        );

        IERC20(path[0]).safeIncreaseAllowance(router, amountInMax);

        amounts = IUniswapV2Router01(router).swapTokensForExactETH(
            amountOut,
            amountInMax,
            path,
            address(this),
            deadline
        );

        IERC20(path[0]).safeApprove(router, 0);

        uint256 donation = (amounts[amounts.length - 1] * percent) / 10000;
        amounts[amounts.length - 1] = amounts[amounts.length - 1] - donation;

        payable(msg.sender).transfer(amounts[amounts.length - 1]);
        pool.transfer(donation);
        if (amountInMax > amounts[0]) IERC20(path[0]).safeTransfer(msg.sender, amountInMax - amounts[0]);
        carbon.increaseCB(msg.sender, donation);

        return amounts;
    }

    function swapExactTokensForETH(
        address router,
        uint256 percent, // over 10000
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        require(10000 > percent, "Invalid percent.");

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        IERC20(path[0]).safeIncreaseAllowance(router, amountIn);

        amounts = IUniswapV2Router01(router).swapExactTokensForETH(
            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 donation = (amounts[amounts.length - 1] * percent) / 10000;
        amounts[amounts.length - 1] = amounts[amounts.length - 1] - donation;

        payable(msg.sender).transfer(amounts[amounts.length - 1]);
        pool.transfer(donation);
        carbon.increaseCB(msg.sender, donation);

        return amounts;
    }

    function swapETHForExactTokens(
        address router,
        uint256 percent, // over 10000
        uint256 amountOut,
        address[] calldata path,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(msg.value > 0, "No msg.value!");
        require(10000 > percent, "Invalid percent.");

        uint256 amountsIn = IUniswapV2Router01(router).getAmountsIn(
            amountOut,
            path
        )[0];

        uint256 donation = (amountsIn * percent) / 10000;

        amountsIn = amountsIn - donation;

        amountOut = IUniswapV2Router01(router).getAmountsOut(
            amountsIn,
            path
        )[1];

        amounts = IUniswapV2Router01(router).swapETHForExactTokens{
            value: amountsIn
        }(amountOut, path, msg.sender, deadline);

        if (msg.value - donation > amountsIn)
            payable(msg.sender).transfer(msg.value - donation - amountsIn);

        pool.transfer(donation);
        carbon.increaseCB(msg.sender, donation);

        return amounts;
    }
}
