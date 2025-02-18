// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {console} from "forge-std/console.sol";

contract AutoLiquidityHook  is BaseHook, Ownable {
    IPoolManager immutable manager;
    mapping(uint256 => int256) liquidityDeltaStore;
    int256 liquidityDelta = 1000000;
    int24 tickLower;
    int24 tickUpper;
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) Ownable(_msgSender()) {
        manager = _poolManager;
        tickLower = TickMath.minUsableTick(60);
        tickUpper = TickMath.maxUsableTick(60);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        // Remove liquidity from the pool
        poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,   // Min tick (full range)
                tickUpper: tickUpper,    // Max tick
                liquidityDelta: liquidityDelta,
                salt: bytes32(0)
            }),
            new bytes(0)
        );


        return (BaseHook.beforeSwap.selector, BeforeSwapDelta.wrap(liquidityDelta), 0);

    }

    // --- AfterSwap: Restore Liquidity ---
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, int128) {

        // Add the liquidity back to the pool
        poolManager.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: tickLower,   // Min tick (full range)
                tickUpper: tickUpper,    // Max tick
                liquidityDelta: -liquidityDelta, // Invert delta (e.g., +1000)
                salt: bytes32(0)
            }),
            new bytes(0)
        );

        // Return no delta modification
        return (this.afterSwap.selector, SafeCast.toInt128(-liquidityDelta));
    }
}