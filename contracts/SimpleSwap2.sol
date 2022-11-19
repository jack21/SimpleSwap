// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

// From https://github.com/AppWorks-School/Blockchain-Resource/tree/main/section3/SimpleSwap

contract SimpleSwap2 is ISimpleSwap, ERC20 {
    // Implement core logic here

    ERC20 public tokenA;
    ERC20 public tokenB;
    uint256 public lastK;

    uint256 public reserveA;
    uint256 public reserveB;

    constructor(address _tokenA, address _tokenB) ERC20("Simple Swap Token", "SToken") {
        require(_isContract(_tokenA), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(_isContract(_tokenB), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        tokenA = ERC20(_tokenA);
        tokenB = ERC20(_tokenB);
    }

    function _isContract(address addr) private view returns (bool) {
        return addr.code.length > 0;
    }

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256) {
        require(
            _isContract(tokenIn) && (address(tokenA) == tokenIn || address(tokenB) == tokenIn),
            "SimpleSwap: INVALID_TOKEN_IN"
        );
        require(
            _isContract(tokenOut) && (address(tokenA) == tokenOut || address(tokenB) == tokenOut),
            "SimpleSwap: INVALID_TOKEN_OUT"
        );
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        address sender = _msgSender();

        uint256 reserveTokenIn = ERC20(tokenIn).balanceOf(address(this));
        uint256 reserveTokenOut = ERC20(tokenOut).balanceOf(address(this));

        uint256 diffK = reserveTokenOut * (reserveTokenIn + amountIn) - lastK;

        // amountOut = reserveTokenOut - lastK / (reserveTokenIn + amountIn)
        uint256 amountOut = diffK / (reserveTokenIn + amountIn);

        require(amountOut > 0, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        require((reserveTokenOut - amountOut) * (reserveTokenIn + amountIn) >= lastK, "SimpleSwap: K");

        ERC20(tokenIn).transferFrom(sender, address(this), amountIn);
        ERC20(tokenOut).transfer(sender, amountOut);

        _updateReserves();

        emit Swap(sender, tokenIn, tokenOut, amountIn, amountOut);

        return amountOut;
    }

    /// @notice Add liquidity to the pool
    /// @param amountAIn The amount of tokenA to add
    /// @param amountBIn The amount of tokenB to add
    /// @return amountA The actually amount of tokenA added
    /// @return amountB The actually amount of tokenB added
    /// @return liquidity The amount of liquidity minted
    function addLiquidity(uint256 amountAIn, uint256 amountBIn) external returns (uint256, uint256, uint256) {
        require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        address sender = _msgSender();
        uint256 _totalSupply = totalSupply();
        uint256 liquidity = 0;
        uint256 actualAmountA = amountAIn;
        uint256 actualAmountB = amountBIn;

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amountAIn * amountBIn);
            lastK = amountAIn * amountBIn;
        } else {
            liquidity = Math.min((amountAIn * _totalSupply) / reserveA, (amountBIn * _totalSupply) / reserveB);

            actualAmountA = (liquidity * reserveA) / _totalSupply;
            actualAmountB = (liquidity * reserveB) / _totalSupply;
        }

        tokenA.transferFrom(sender, address(this), actualAmountA);
        tokenB.transferFrom(sender, address(this), actualAmountB);

        _updateReserves();

        _mint(sender, liquidity);

        emit AddLiquidity(sender, actualAmountA, actualAmountB, liquidity);

        return (actualAmountA, actualAmountB, liquidity);
    }

    /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) external returns (uint256, uint256) {
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        address sender = _msgSender();
        uint256 _totalSupply = totalSupply();
        uint256 amountA = (liquidity * reserveA) / _totalSupply;
        uint256 amountB = (liquidity * reserveB) / _totalSupply;

        _transfer(sender, address(this), liquidity);
        _burn(address(this), liquidity);

        tokenA.transfer(sender, amountA);
        tokenB.transfer(sender, amountB);

        _updateReserves();

        emit RemoveLiquidity(sender, amountA, amountB, liquidity);

        return (amountA, amountB);
    }

    function _updateReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }

    /// @notice Get the reserves of the pool
    /// @return reserveA The reserve of tokenA
    /// @return reserveB The reserve of tokenB
    function getReserves() external view returns (uint256, uint256) {
        return (reserveA, reserveB);
    }

    /// @notice Get the address of tokenA
    /// @return tokenA The address of tokenA
    function getTokenA() external view returns (address) {
        return address(tokenA);
    }

    /// @notice Get the address of tokenB
    /// @return tokenB The address of tokenB
    function getTokenB() external view returns (address) {
        return address(tokenB);
    }
}
