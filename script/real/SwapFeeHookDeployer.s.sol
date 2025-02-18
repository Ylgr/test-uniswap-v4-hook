// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../lib/v4-core/src/types/PoolKey.sol";
import "../../src/SwapFeeHook.sol";
import "../../test/utils/HookMiner.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {Constants} from "../base/Constants.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";

contract SwapFeeHookDeployer is Script, Constants {
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    address owner = 0x85980dcd69b253C480ea730e8FA33C3F33De5a78;
    using PoolIdLibrary for PoolKey;

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(POOLMANAGER, owner);
        (address hookAddress, bytes32 salt) =
                            HookMiner.find(CREATE2_DEPLOYER, flags, type(SwapFeeHook).creationCode, constructorArgs);
        console.log("Hook address: %s", hookAddress);
        console.logBytes32(salt);
        // Deploy the hook using CREATE2
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SwapFeeHook hook = new SwapFeeHook{salt: salt}(IPoolManager(POOLMANAGER), owner);
        vm.stopBroadcast();
        console.log("SwapFeeHook deployed contract:", address(hook));
        require(address(hook) == hookAddress, "SwapFeeHookDeployer: hook address mismatch");
    }
}