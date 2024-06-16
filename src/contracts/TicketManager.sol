// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import {SeasonPassManager} from "../contracts/SeasonPassManager.sol";

/**
 * @title Smart Contract that manages a season pass ticket for live events.
 * @author Carlos Alba
 * @notice This contract uses Blockchain technology to manage a the ticket section of the match
 *
 */
contract TicketManager is Ownable {
    error TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner();
    error TicketManager_SeatNotPossibleToFree();
    error TicketManager_TransferFailed();

    error TicketManager_MaxSeatsInZone();
    error TicketManager_WrongInformationGiven();
    error TicketManager_MoreSeasonPassesThanExpected(uint256 length, uint256 maxFans);
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
    event TicketManager_AdvancedToNextMatch(uint256 indexed numberOfCurrentMatch);
    event TicketManager_SetNewSeason();

    /**
     * @dev
     * -numberOfCurrentMatch : The Number of the current Match
     * -seasonPassManager : The contract that has all the seasonPass functionality
     * -s_TicketSeats : Stores the information related to the seats at every match
     * -currentPricesPerZone : Prizes of tickets for every zone for the current match
     */
    uint256 private numberOfCurrentMatch;
    SeasonPassManager private seasonPassManager;

    mapping(uint256 seatId => address[400] isSeatUsed) private s_TicketSeats;
    uint256[] private currentPricesPerZone;

    /**
     *
     * @param seasonPassManager_ : Address of the contract that contains the SeasonPassManager
     * @param numberOfCurrentMatch_  : Number of the match when youre deploying the contract.
     * Normally should be 1, but it might be deployed after the season started
     */
    constructor(address seasonPassManager_, uint256 numberOfCurrentMatch_) Ownable(msg.sender) {
        seasonPassManager = SeasonPassManager(seasonPassManager_);
        numberOfCurrentMatch = numberOfCurrentMatch_;
    }

    /**
     * Function that starts a new Season
     */
    function setNewSeason() external onlyOwner {
        numberOfCurrentMatch = 1;
        emit TicketManager_SetNewSeason();
    }

    /**
     *  Function that advances the match after that one has been played. Allows for an update on prices
     * @param newPrices Array containing the new prices for the tickets of this next particular match
     * You can send an empty array to omit updating the Price array.
     */
    function advanceMatch(uint256[] memory newPrices) external onlyOwner {
        numberOfCurrentMatch++;
        if (newPrices.length != 0) {
            currentPricesPerZone = newPrices;
            emit TicketManager_TicketPrizesChanged(newPrices);
        }
        emit TicketManager_AdvancedToNextMatch(numberOfCurrentMatch);
    }

    /**
     * Private function that checks if the seat being bought is available
     * @param buyer : User that wants to buy the ticket
     * @param seat : Seat linked to the ticket
     */
    function _buyTicket(address buyer, SeasonPassManager.Seat memory seat)
        private
        returns (SeasonPassManager.Seat memory)
    {
        if (
            seat.rowSeatNumber == 0 || buyer == seat.seatOwner
                || (seat.seatOwner != address(0) && s_TicketSeats[seat.seatId][numberOfCurrentMatch] != seat.seatOwner)
        ) {
            revert TicketManager_SeatIsNotFreeOrBuyerIsSeatOwner();
        }

        s_TicketSeats[seat.seatId][numberOfCurrentMatch] = buyer;
        return seat;
    }

    /**
     * Function called by users without using the webpage. You do not need to use the webpage, you can interact
     * directly with the contract with this function. Checks that the value sent in the transaction is greater than the price and
     * calls `_buyTicket`
     * @param seatId_ Id of the seat linked to the ticket
     */
    function buyTicket(uint256 seatId_) external payable returns (SeasonPassManager.Seat memory boughtSeat) {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(seatId_);

        if (msg.value < getCurrentPricePerZone(seat.zone)) {
            revert TicketManager_NotEnoughETHSent();
        }
        boughtSeat = _buyTicket(msg.sender, seat);
    }

    /**
     * This function is called by the webpage where the tickets are sold.
     * @param seatId_ : id of the seat linked to the ticket
     * @param buyer : person that buys the ticket
     */
    function buyTicketFromWeb(uint256 seatId_, address buyer)
        external
        onlyOwner
        returns (SeasonPassManager.Seat memory boughtSeat)
    {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(seatId_);
        boughtSeat = _buyTicket(buyer, seat);
    }

    /**
     * This private functions checks if the seat can be made available for tickets for this match
     * and frees it.
     * @param seat : Seat going to be freed
     * @param owner_ : Owner of the seat freeing the seat for this match so that other people can seat there
     */
    function _freeTheSeat(SeasonPassManager.Seat memory seat, address owner_) private {
        if (
            seat.rowSeatNumber == 0 || seat.seatOwner != owner_
                || s_TicketSeats[seat.seatId][numberOfCurrentMatch] != address(0)
        ) {
            revert TicketManager_SeatNotPossibleToFree();
        }
        s_TicketSeats[seat.seatId][numberOfCurrentMatch] = seat.seatOwner;
        emit TicketManager_FreedSeat(seat.seatId, seat.zone);
    }
    /**
     * This function is called by the webpage where the tickets are sold.
     * @param seatId_ : id of Seat going to be freed
     * @param owner_ : Owner of the seat freeing the seat for this match so that other people can seat there
     */

    function freeTheSeatFromWeb(uint256 seatId_, address owner_) external onlyOwner {
        SeasonPassManager.Seat memory seat = seasonPassManager.getSeat(seatId_);
        _freeTheSeat(seat, owner_);
    }

    /**
     * Function called by users without using the webpage. You do not need to use the webpage, you can interact
     * directly with the contract with this function. Allows msg.sender to directly free the seat for the match
     * without interacting with the webpage.
     *
     */
    function freeTheSeat() external {
        SeasonPassManager.Seat memory seat =
            seasonPassManager.getSeat(seasonPassManager.getSeasonPass(msg.sender).seatId);
        _freeTheSeat(seat, msg.sender);
    }

    function transferMoney() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            revert TicketManager_TransferFailed();
        }
    }

    ////////////////////
    //GETTERS///////////
    ////////////////////

    function getNumberOfCurrentMatch() external view returns (uint256) {
        return numberOfCurrentMatch;
    }

    function getSeasonPassManagerContract() external view returns (SeasonPassManager) {
        return seasonPassManager;
    }

    function getUsageOfSeat(uint256 seatId_) external view returns (address[400] memory) {
        return s_TicketSeats[seatId_];
    }

    function getCurrentPrices() external view returns (uint256[] memory) {
        return currentPricesPerZone;
    }

    function getCurrentPricePerZone(uint256 zone) public view returns (uint256) {
        if (zone < currentPricesPerZone.length) {
            return currentPricesPerZone[zone];
        }
        return 0;
    }

    function getSeatTicketBuyer(uint256 seatId_, uint256 matchId) external view returns (address) {
        return s_TicketSeats[seatId_][matchId];
    }
}
