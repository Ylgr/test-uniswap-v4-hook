// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import "../src/DynamicFeeHook.sol";

contract DynamicFeeHookTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    DynamicFeeHook hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

//    address feeCollector = address(0x1234);

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG
//                Hooks.ALL_HOOK_MASK
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("DynamicFeeHook.sol:DynamicFeeHook", constructorArgs, flags);
        hook = DynamicFeeHook(flags);
//        hook = new DynamicFeeHook(manager);
        hook.setFee(100_000);
        // Create the pool
        key = PoolKey(currency0, currency1, LPFeeLibrary.DYNAMIC_FEE_FLAG, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);
        {
            uint128 liquidityAmount = 100e18;

            (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
                SQRT_PRICE_1_1,
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                liquidityAmount
            );

            (tokenId,) = posm.mint(
                key,
                tickLower,
                tickUpper,
                liquidityAmount,
                amount0Expected + 1,
                amount1Expected + 1,
                address(this),
                block.timestamp,
                ZERO_BYTES
            );
        }
    }

    function test_afterSwap() public {
        address sender = vm.addr(1);
        console.log("sender: %s", sender);
        console.log("address(hook): %s", address(hook));
        currency0.transfer(sender, 10e18);
        console.log("balance before1: %s", currency0.balanceOf(sender));
        console.log("balance before2: %s", currency1.balanceOf(sender));
        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e18; // negative number indicates exact input swap!
        vm.startPrank(sender);
        console.log("currency0.unwrap(): %s", address(uint160(currency0.toId())));
        IERC20(address(uint160(currency0.toId()))).approve(address(swapRouter), 10e18);
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        vm.stopPrank();
        console.log("balance after1: %s", currency0.balanceOf(sender));
        console.log("balance after2: %s", currency1.balanceOf(sender));
    }
}