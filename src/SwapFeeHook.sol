// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IERC20} from "../lib/uniswap-hooks/lib/v4-core/lib/openzeppelin-contracts/lib/erc4626-tests/ERC4626.prop.sol";
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
    IPoolManager immutable manager;
    address feeCollector;

    constructor(IPoolManager _poolManager, address _feeCollector) BaseHook(_poolManager) Ownable(_msgSender()) {
        manager = _poolManager;
        feeCollector = _feeCollector;
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


        // if exactOutput swap, get the absolute output amount

        if (amountUnspecified < 0) amountUnspecified = -amountUnspecified;

//        // 10% amount for each swap
//        uint256 fee = amount / 10;
//        manager.mint(address (this), CurrencyLibrary.toId(inputCurrency), fee);
//        return (BaseHook.afterSwap.selector, fee.toInt128());
        console.log("amount: %s", amountUnspecified);
        uint256 feeAmount = uint256(int256(amountUnspecified)).mulWadDown(1e17);
        // mint ERC6909 as its cheaper than ERC20 transfer
        poolManager.mint(feeCollector, currencyUnspecified.toId(), feeAmount);
//        poolManager.mint(feeCollector, key.currency0.toId(), feeAmount);
        return (BaseHook.afterSwap.selector, feeAmount.toInt128());
    }

}