// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {SeasonPassManager} from "../src/contracts/SeasonPassManager.sol";

contract DeploySeasonPassManager is Script {
    function run() public returns (SeasonPassManager) {
        vm.startBroadcast();
        SeasonPassManager seasonPassManager = new SeasonPassManager(1, 100, 500, 10, 1 ether);
        vm.stopBroadcast();
        return seasonPassManager;
    }
}
