// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SeasonPassManager} from "../src/contracts/SeasonPassManager.sol";
import {DeploySeasonPassManager} from "../script/DeploySeasonPassManager.s.sol";
import {TicketManager} from "../src/contracts/TicketManager.sol";

contract TicketManagerTest is Test {
    SeasonPassManager seasonPassManager;
    TicketManager ticketManager;

    function setUp() public {
        DeploySeasonPassManager deployer = new DeploySeasonPassManager();
        (seasonPassManager, ticketManager) = deployer.run();
    }

    modifier addFansAndSeats() {
        seasonPassManager = new SeasonPassManager(1, 100, 200, 10, 1 ether);
        vm.startPrank(seasonPassManager.owner());
        address[] memory fans = new address[](3);
        fans[0] = address(0x1);
        fans[1] = address(0x2);
        fans[2] = address(0x3);
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](4);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seatIds[3] = SeasonPassManager.Seat(4, address(0), 1, 4, 4);
        seasonPassManager.changeNumberOfSeasonIds(fans);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        int256[] memory variation = new int256[](10);
        variation[1] = 4;
        variation[2] = 6;
        variation[3] = 9;
        seasonPassManager.modifyAvailableSeats(variation);
        vm.stopPrank();
        ticketManager = new TicketManager(address(seasonPassManager), 1);
        vm.startPrank(ticketManager.owner());
        _;
    }

    function testConstructor() public addFansAndSeats {
        assertEq(ticketManager.getNumberOfCurrentMatch(), 1);
    }

    function testSetNewSeason() public addFansAndSeats {
        assertEq(ticketManager.getNumberOfCurrentMatch(), 1);
        ticketManager = new TicketManager(address(seasonPassManager), 5);
        assertEq(ticketManager.getNumberOfCurrentMatch(), 5);
        ticketManager.setNewSeason();
        assertEq(ticketManager.getNumberOfCurrentMatch(), 1);
    }

    function testAdvanceMatch() public addFansAndSeats {
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        assertEq(ticketManager.getCurrentPricePerZone(1), 1 ether);
        assertEq(ticketManager.getNumberOfCurrentMatch(), 2);
        uint256[] memory old;
        ticketManager.advanceMatch(old);
        assertEq(ticketManager.getCurrentPricePerZone(1), 1 ether);
        assertEq(ticketManager.getNumberOfCurrentMatch(), 3);
    }

    function testBuyTicketRevertsNotEnoughEth() public addFansAndSeats {
        vm.deal(address(0x20), 5 ether);
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        vm.stopPrank();
        vm.startPrank(address(0x20));
        vm.expectRevert(TicketManager.TicketManager_NotEnoughETHSent.selector);
        ticketManager.buyTicket{value: 0.5 ether}(4);
    }

    function testBuyTicketRevertsSeatDoesNotExist() public addFansAndSeats {
        vm.deal(address(0x20), 5 ether);
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        vm.stopPrank();
        vm.startPrank(address(0x20));
        vm.expectRevert(TicketManager.TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner.selector);
        ticketManager.buyTicket{value: 1 ether}(6);
    }

    function testBuyTicketRevertsCallerIsOwner() public addFansAndSeats {
        vm.deal(address(0x1), 5 ether);
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        vm.stopPrank();
        vm.startPrank(address(0x1));
        vm.expectRevert(TicketManager.TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner.selector);
        ticketManager.buyTicket{value: 1 ether}(1);
    }

    function testBuyTicketRevertsSeatIsNotFreed() public addFansAndSeats {
        vm.deal(address(0x20), 5 ether);
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        vm.stopPrank();
        vm.startPrank(address(0x20));
        vm.expectRevert(TicketManager.TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner.selector);
        ticketManager.buyTicket{value: 1 ether}(1);
    }

    function testBuyTicketPayableNotOwnedSeat() public addFansAndSeats {
        vm.deal(address(0x20), 5 ether);
        uint256[] memory newPrices_ = new uint256[](2);
        newPrices_[0] = 0.5 ether;
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        uint256[] memory pricess = ticketManager.getCurrentPrices();
        for (uint256 i = 0; i < pricess.length; i++) {
            console2.log(pricess[i]);
        }
        vm.stopPrank();
        vm.startPrank(address(0x20));
        ticketManager.buyTicket{value: 1 ether}(4);
        assertEq(ticketManager.getSeatTicketBuyer(4, 2), address(0x20));
    }

    function testBuyTicketPayableFreedSeat() public addFansAndSeats {
        vm.deal(address(0x20), 5 ether);
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        vm.stopPrank();
        vm.prank(address(0x1));
        ticketManager.freeTheSeat();
        vm.startPrank(address(0x20));
        ticketManager.buyTicket{value: 1 ether}(4);
        assertEq(ticketManager.getSeatTicketBuyer(4, 2), address(0x20));
    }

    function testBuyTicketWeb() public addFansAndSeats {
        vm.deal(address(0x20), 5 ether);
        uint256[] memory newPrices_ = new uint256[](10);
        newPrices_[1] = 1 ether;
        ticketManager.advanceMatch(newPrices_);
        ticketManager.buyTicketFromWeb(4, address(0x20));
        assertEq(ticketManager.getSeatTicketBuyer(4, 2), address(0x20));
    }

    function testFreeTheSeatRevertsSeatDoesNotExist() public addFansAndSeats {
        vm.stopPrank();
        vm.startPrank(address(0x20));
        vm.expectRevert(TicketManager.TicketManager_SeatNotPossibleToFree.selector);
        ticketManager.freeTheSeat();
    }

    function testFreeTheSeatRevertsSeatAlreadyFreed() public addFansAndSeats {
        vm.stopPrank();
        vm.startPrank(address(0x1));
        ticketManager.freeTheSeat();
        vm.expectRevert(TicketManager.TicketManager_SeatNotPossibleToFree.selector);
        ticketManager.freeTheSeat();
    }

    function testFreeTheSeat() public addFansAndSeats {
        vm.stopPrank();
        vm.startPrank(address(0x1));
        ticketManager.freeTheSeat();
        assertEq(ticketManager.getSeatTicketBuyer(1, 1), address(0x1));
    }
}
