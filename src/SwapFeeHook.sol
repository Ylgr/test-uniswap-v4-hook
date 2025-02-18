// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {console} from "forge-std/console.sol";

contract SwapFeeHook is BaseHook, Ownable {
    using CurrencyLibrary for Currency;
    using FixedPointMathLib for uint256;
    using SafeCast for uint256;
    address feeCollector;
    uint256 internal zeroToOneFee;
    uint256 internal oneToZeroFee;

    constructor(IPoolManager _poolManager, address _owner) BaseHook(_poolManager) Ownable(_owner)  {
        feeCollector = _owner;
        zeroToOneFee = 0; // 0%
        oneToZeroFee = 8e17; // 80%
    }

    function setFee(uint256 _zeroToOneFee, uint256 _oneToZeroFee) external onlyOwner {
        zeroToOneFee = _zeroToOneFee;
        oneToZeroFee = _oneToZeroFee;
    }

    function setFeeCollector(address _feeCollector) public onlyOwner {
        feeCollector = _feeCollector;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata params , BalanceDelta delta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        bool isCurrency0Specified = (params.amountSpecified < 0 == params.zeroForOne);
        (Currency currencyUnspecified, int128 amountUnspecified) =
            (isCurrency0Specified) ? (key.currency1, delta.amount1()) : (key.currency0, delta.amount0());
        if (amountUnspecified < 0) amountUnspecified = -amountUnspecified;
        uint256 feeAmount = params.zeroForOne ?
            uint256(int256(amountUnspecified)).mulWadDown(zeroToOneFee) :
            uint256(int256(amountUnspecified)).mulWadDown(oneToZeroFee);
        poolManager.take(currencyUnspecified, feeCollector, feeAmount);
        return (BaseHook.afterSwap.selector, feeAmount.toInt128());
    }

}