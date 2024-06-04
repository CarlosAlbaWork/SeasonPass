// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SeasonPassManager} from "../src/SeasonPassManager.sol";

/**
 * @title Smart Contract that manages a season pass ticket for live events.
 * @author Carlos Alba
 * @notice This contract uses Blockchain technology to manage a the ticket section of the match
 *
 */

contract TicketManager is Ownable {
    error TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner();
    error TicketManager_SeatNotPossibleToFree();

    error TicketManager_MaxSeatsInZone();
    error TicketManager_WrongInformationGiven();
    error TicketManager_MoreSeasonPassesThanExpected(
        uint256 length,
        uint256 maxFans
    );
    error TicketManager_NotOwnerOfSeasonPass();
    error TicketManager_ForbiddenAccess();
    error TicketManager_NotEnoughETHSent();

    struct Ticket {
        uint256 ticketId;
        uint256 seatId;
    }

    event TicketManager_BoughtTicket(uint256 indexed seatId);
    event TicketManager_TicketPrizesChanged(uint256[] indexed prizes);
    event TicketManager_FreedSeat(uint256 indexed seatId, uint256 indexed zone);
    event TicketManager_AdvancedToNextMatch(
        uint256 indexed numberOfCurrentMatch
    );
    event TicketManager_SetNewSeason();

    //Include all possible matches like Copa del Rey, friendly, or playoffs

    uint256 private numberOfCurrentMatch;
    SeasonPassManager private seasonPassManager;

    mapping(uint256 seatId => address[] isSeatUsed) s_TicketSeats;
    uint256[] currentPricesPerZone;

    constructor(address seasonPassManager_) Ownable(msg.sender) {
        seasonPassManager = SeasonPassManager(seasonPassManager_);
        numberOfCurrentMatch = 1;
    }

    function setNewSeason() external onlyOwner {
        numberOfCurrentMatch = 1;
        emit TicketManager_SetNewSeason();
    }

    function advanceMatch(uint256[] memory newPrices) external onlyOwner {
        numberOfCurrentMatch++;
        if (newPrices.length != 0) {
            currentPricesPerZone = newPrices;
            emit TicketManager_TicketPrizesChanged(newPrices);
        }
        emit TicketManager_AdvancedToNextMatch(numberOfCurrentMatch);
    }

    function buyTicket(
        uint256 seatId_
    ) external payable returns (SeasonPassManager.Seat memory) {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(seatId_);

        if (msg.value < currentPricesPerZone[seat.zone]) {
            revert TicketManager_NotEnoughETHSent();
        }

        if (
            seat.rowSeatNumber == 0 ||
            s_TicketSeats[seatId_][numberOfCurrentMatch] != seat.seatOwner ||
            msg.sender == seat.seatOwner
        ) {
            revert TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner();
        }

        s_TicketSeats[seatId_][numberOfCurrentMatch] = msg.sender;
        return seat;
    }

    //This function is used from Team Webpage. Web2
    function buyTicketFromWeb(
        uint256 seatId_,
        address buyer
    ) external onlyOwner returns (SeasonPassManager.Seat memory) {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(seatId_);

        if (
            seat.rowSeatNumber == 0 ||
            s_TicketSeats[seatId_][numberOfCurrentMatch] != seat.seatOwner ||
            buyer == seat.seatOwner
        ) {
            revert TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner();
        }
        s_TicketSeats[seatId_][numberOfCurrentMatch] = buyer;
        return seat;
    }

    //This function is used from Team Webpage. Web2
    function freeTheSeatFromWeb(
        uint256 seatId_,
        address owner_
    ) external onlyOwner {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(seatId_);
        if (
            seat.rowSeatNumber == 0 ||
            seat.seatOwner != owner_ ||
            s_TicketSeats[seatId_][numberOfCurrentMatch] != address(0)
        ) {
            revert TicketManager_SeatNotPossibleToFree();
        }
        s_TicketSeats[seatId_][numberOfCurrentMatch] = seat.seatOwner;
        emit TicketManager_FreedSeat(seatId_, seat.zone);
    }

    function freeTheSeat() external {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(
            seasonPassManager.getSeasonPass(msg.sender).seatId
        );
        if (
            seat.rowSeatNumber == 0 ||
            seat.seatOwner != msg.sender ||
            s_TicketSeats[seat.seatId][numberOfCurrentMatch] != address(0)
        ) {
            revert TicketManager_SeatNotPossibleToFree();
        }
        s_TicketSeats[seat.seatId][numberOfCurrentMatch] = seat.seatOwner;
        emit TicketManager_FreedSeat(seat.seatId, seat.zone);
    }
}
