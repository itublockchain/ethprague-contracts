// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./IUniswapV2Router01.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DonateOnDEX {
    using SafeERC20 for IERC20;

    address payable public pool;

    constructor(address poolAddress) {
        pool = payable(poolAddress);
    }

    function swapExactETHForTokens(
        address router,
        uint256 percent, // over 10000
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(msg.value > 0, "No msg.value!");

        uint256 donation = (msg.value * percent) / 10000;

        amounts = IUniswapV2Router01(router).swapExactETHForTokens{
            value: msg.value - donation
        }(amountOutMin, path, address(this), deadline);

        IERC20(path[path.length - 1]).safeTransfer(
            msg.sender,
            amount[path.length - 1]
        );
        pool.transfer(donation);
        return;
    }

    function swapTokensForExactETH(
        address router,
        uint256 percent, // over 10000
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(
            msg.sender,
            address(this),
            IUniswapV2Router01(router).getAmountsIn(amountOut, path)[0]
        );

        IERC20(path[0]).safeIncreaseAllowance(address(router), amountInMax);

        amounts = IUniswapV2Router01(router).swapTokensForExactETH(
            amountOut,
            amountInMax,
            path,
            address(this),
            deadline
        );

        IERC20(path[0]).safeApprove(address(routerContract), 0);

        uint256 donation = (amounts[amounts.length - 1] * percent) / 10000;
        amounts[amounts.length - 1] = amounts[amounts.length - 1] - donation;

        payable(msg.sender).transfer(amounts[amounts.length - 1]);
        pool.transfer(donation);

        return;
    }

    function swapExactTokensForETH(
        address router,
        uint256 percent, // over 10000
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts) {
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);

        IERC20(path[0]).safeIncreaseAllowance(
            address(routerContract),
            amountIn
        );

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

        return;
    }

    function swapETHForExactTokens(
        address router,
        uint256 percent, // over 10000
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts) {
        require(msg.value > 0, "No msg.value!");
        uint256 amountsIn = IUniswapV2Router01(router).getAmountsIn(
            amountOut,
            path
        );

        uint256 donation = (amountsIn * percent) / 10000;

        amountOut = (amountOut * percent) / 10000;

        amounts = IUniswapV2Router01(router).swapETHForExactTokens{
            value: msg.value - donation
        }(amountOut, path, address(this), deadline);

        IERC20(path[path.length - 1]).safeTransfer(
            msg.sender,
            amount[path.length - 1]
        );
        pool.transfer(donation);
        return;
    }
}
