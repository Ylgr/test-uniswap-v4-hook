// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {console} from "forge-std/console.sol";

contract DynamicFeeHook  is BaseHook, Ownable {
    using LPFeeLibrary for uint24;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) Ownable(_msgSender()) {
    }

    uint24 internal fee;
    IPoolManager manager;

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function setManager(IPoolManager _manager) external {
        manager = _manager;
    }

    function setFee(uint24 _fee) external {
        fee = _fee;
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
    external
    view
    override
    returns (bytes4, BeforeSwapDelta, uint24)
    {
        // attach the fee flag to `fee` to enable overriding the pool's stored fee
        console.log("fee | LPFeeLibrary.OVERRIDE_FEE_FLAG: %s", fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, fee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function forcePoolFeeUpdate(PoolKey calldata _key, uint24 _fee) external {
        manager.updateDynamicLPFee(_key, _fee);
    }
}