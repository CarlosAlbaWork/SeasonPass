// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {SeasonPassManager} from "../src/contracts/SeasonPassManager.sol";
import {TicketManager} from "../src/contracts/TicketManager.sol";

contract DeploySeasonPassManager is Script {
    function run() public returns (SeasonPassManager, TicketManager) {
        vm.startBroadcast();
        SeasonPassManager seasonPassManager = new SeasonPassManager(1, 100, 500, 10, 1 ether);
        TicketManager ticketManager = new TicketManager(address(seasonPassManager), 1);
        vm.stopBroadcast();
        return (seasonPassManager, ticketManager);
    }
}
