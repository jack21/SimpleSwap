// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { console } from "hardhat/console.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    address tokenA;
    address tokenB;
    uint256 reserveA;
    uint256 reserveB;

    constructor(address _tokenA, address _tokenB) ERC20("LP", "ULP") {
        require(_tokenA != address(0), "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        require(_tokenB != address(0), "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    /// @notice Swap tokenIn for tokenOut with amountIn
    /// @param tokenIn The address of the token to swap from
    /// @param tokenOut The address of the token to swap to
    /// @param amountIn The amount of tokenIn to swap
    /// @return amountOut The amount of tokenOut received
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external returns (uint256 amountOut) {
        // 檢查
        require(tokenIn == tokenA || tokenIn == tokenB, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == tokenA || tokenOut == tokenB, "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        // 計算
        uint256 _k = reserveA * reserveB;
        uint256 _amountOut = 0;
        if (tokenIn == tokenA) {
            // _amountOut = reserveB - _k / (reserveA + amountIn); // 這算法算出來是 1，算法應該也可以，但不確定，上課再來問導師
            uint256 _newReserveA = reserveA + amountIn;
            uint256 _newK = _newReserveA * reserveB;
            _amountOut = (_newK - _k) / _newReserveA;
            reserveA += amountIn;
            reserveB -= _amountOut;
        } else {
            // _amountOut = reserveA - _k / (reserveB + amountIn); // 這算法算出來是 1，算法應該也可以，但不確定，上課再來問導師
            uint256 _newReserveB = reserveA + amountIn;
            uint256 _newK = _newReserveB * reserveA;
            _amountOut = (_newK - _k) / _newReserveB;
            reserveA -= _amountOut;
            reserveB += amountIn;
        }
        require(_amountOut > 0, "SimpleSwap: INSUFFICIENT_OUTPUT_AMOUNT");
        // 轉帳
        ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        ERC20(tokenOut).approve(address(this), _amountOut);
        ERC20(tokenOut).transferFrom(address(this), msg.sender, _amountOut);
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, _amountOut);
        return _amountOut;
    }

    /// @notice Add liquidity to the pool
    /// @param amountAIn The amount of tokenA to add
    /// @param amountBIn The amount of tokenB to add
    /// @return amountA The actually amount of tokenA added
    /// @return amountB The actually amount of tokenB added
    /// @return liquidity The amount of liquidity minted
    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // 檢查
        require(amountAIn > 0 && amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        // 計算
        uint256 _amountAIn = 0;
        uint256 _amountBIn = 0;
        uint256 _liquidity = 0;
        if (totalSupply() == 0) {
            _amountAIn = amountAIn;
            _amountBIn = amountBIn;
            _liquidity = Math.sqrt(_amountAIn * _amountBIn);
        } else {
            _amountAIn = Math.min(amountAIn, (amountBIn * reserveA) / reserveB);
            _amountBIn = Math.min(amountBIn, (amountAIn * reserveB) / reserveA);
            _liquidity = Math.sqrt(_amountAIn * _amountBIn);
        }
        // 轉帳
        ERC20(tokenA).transferFrom(msg.sender, (address(this)), _amountAIn);
        ERC20(tokenB).transferFrom(msg.sender, (address(this)), _amountBIn);
        _mint(msg.sender, _liquidity);
        reserveA += _amountAIn;
        reserveB += _amountBIn;
        emit AddLiquidity(msg.sender, _amountAIn, _amountBIn, _liquidity);
        return (_amountAIn, _amountBIn, _liquidity);
    }

    /// @notice Remove liquidity from the pool
    /// @param liquidity The amount of liquidity to remove
    /// @return amountA The amount of tokenA received
    /// @return amountB The amount of tokenB received
    function removeLiquidity(uint256 liquidity) external returns (uint256 amountA, uint256 amountB) {
        // 檢查
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");
        // 計算
        uint256 _totalSupply = totalSupply();
        amountA = (liquidity * reserveA) / _totalSupply;
        amountB = (liquidity * reserveB) / _totalSupply;
        // 轉帳
        ERC20(tokenA).transfer(msg.sender, amountA);
        ERC20(tokenB).transfer(msg.sender, amountB);
        // 燒毀
        // (不懂，addLiquidity 時是 mint 給 msg.sender，為什麼 removeLiquidity 時要先把 LP 轉回來再 burn，為什麼不直接 burn(msg.sender)，上課再來問)
        _transfer(msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);
        // 記錄
        reserveA -= amountA;
        reserveB -= amountB;
        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    /// @notice Get the reserves of the pool
    /// @return _reserveA The reserve of tokenA
    /// @return _reserveB The reserve of tokenB
    function getReserves() external view returns (uint256 _reserveA, uint256 _reserveB) {
        return (reserveA, reserveB);
    }

    /// @notice Get the address of tokenA
    /// @return _tokenA The address of tokenA
    function getTokenA() external view returns (address _tokenA) {
        return tokenA;
    }

    /// @notice Get the address of tokenB
    /// @return _tokenB The address of tokenB
    function getTokenB() external view returns (address _tokenB) {
        return tokenB;
    }
}
