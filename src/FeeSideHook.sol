// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

contract FeeSideHook is BaseHook, Ownable {
    using LPFeeLibrary for uint24;

    constructor(IPoolManager _poolManager, address _owner) BaseHook(_poolManager) Ownable(_owner) {
        manager = _poolManager;
        zeroToOneFee = 0; // 0%
        oneToZeroFee = 800_000; // 80%
    }

    uint24 internal zeroToOneFee;
    uint24 internal oneToZeroFee;
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

    function setFee(uint24 _zeroToOneFee, uint24 _oneToZeroFee) external onlyOwner {
        zeroToOneFee = _zeroToOneFee;
        oneToZeroFee = _oneToZeroFee;
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata params, bytes calldata)
    external
    view
    override
    returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (params.zeroForOne) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, zeroToOneFee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
        }
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, oneToZeroFee | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function forcePoolFeeUpdate(PoolKey calldata _key, uint24 _fee) external onlyOwner {
        manager.updateDynamicLPFee(_key, _fee);
    }
}