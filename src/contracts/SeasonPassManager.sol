// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Smart Contract that manages a season pass ticket for live events.
 * @author Carlos Alba
 * @notice This contract uses Blockchain technology to manage a Season Pass with different functionality
 *
 */
contract SeasonPassManager is Ownable {
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// ERRORS //////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    error SeasonPass_CalledInWrongStage();
    error SeasonPass_FanAddedBefore();
    error SeasonPass_FanHasNoSeasonPass();
    error SeasonPass_MaximumFansAdded();
    error SeasonPass_SeatIsNotFree();
    error SeasonPass_MaxSeatsInZone();
    error SeasonPass_WrongInformationGiven();
    error SeasonPass_MoreSeasonPassesThanExpected();
    error SeasonPass_NotOwnerOfSeasonPass();
    error SeasonPass_NotEnoughETHSent();
    error SeasonPass_SeasonPassNotRenewed();
    error SeasonPass_MatchEnteredBefore();
    error SeasonPass_TransferFailed();

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// STRUCTS /////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * Seat Struct
     * @param seatId : Id of the seat
     * @param seatOwner : Owner of the seat for the season
     * @param zone : Zone where the seat is located
     * @param row : Row of the seat
     * @param rowSeatNumber : Number of the seat in the row
     *
     */
    struct Seat {
        uint256 seatId;
        address seatOwner;
        uint256 zone;
        uint256 row;
        uint256 rowSeatNumber;
    }

    /**
     * SeasonPass Struct
     * @param idOfSeasonPass : Number of the season Pass. Every year gets lower if fans with a lower number dont renew the pass
     * @param seatId : Id of the seat
     * @param seasonNumber : Number of the season of the Pass. Stored to check when trying to enter if he renewed
     * @param matchesGoneToStadium : Array that stores the matches that he went to
     *
     */
    struct SeasonPass {
        uint256 idOfSeasonPass;
        uint256 seatId;
        uint256 seasonNumber;
        bool[500] matchesGoneToStadium;
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// ENUMS ///////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * Stages Enum
     * @param RENEWALS : Stage where former SeasonPass holders have priority to renew
     * @param SEAT_CHANGES : Stage where former SeasonPass holders have priority to change the seat if wanted
     * @param NEW_FANS : Stage where new SeasonPass holders are added, using the remaining available seats of the stadium
     * @param REGULAR_SEASON : Stage where the Season is ongoing
     *
     */
    enum Stages {
        RENEWALS,
        SEAT_CHANGES,
        NEW_FANS,
        REGULAR_SEASON
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// EVENTS //////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    event SeasonPass_NumberOfSeatsModified(uint256 indexed oldnumberOfMaxSeats, uint256 indexed newnumberOfMaxSeats);
    event SeasonPass_UpdatedSeatAvailability();
    event SeasonPass_UpdatedSympathizerFee(uint256 indexed oldSympathizerFee, uint256 indexed newSympathizerFee);
    event SeasonPass_NewSeasonStarted(
        uint256 indexed numberOfMaxFans_, uint256 indexed numberOfMaxSeats_, uint256 indexed numberOfZones_
    );
    event SeasonPass_AdvancedTheStage(Stages newstage);
    event SeasonPass_UpdatedNumberOfSeasonPassIds();
    event SeasonPass_DeletedOldNumberOfSeasonPassIds();
    event SeasonPass_SetSeatAvailability();
    event SeasonPass_NewSympathizer(address indexed sympathizer, uint256 indexed numberOfSympathizers);
    event SeasonPass_NewFan(address indexed fan, uint256 indexed numberOfFans);
    event SeasonPass_ChangeSeat(address indexed fan);

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// VARIABLES ///////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * Variables
     * -seasonNumber : Number of the season Pass. Every new season gets updated
     * -numberOfMaxFans : Maximum number of fans allowed to have a SeasonPass at the same time
     * -numberOfCurrentFans : Current number of fans having a SeasonPass
     * -numberOfMaxSeats : Maximum number of seats at the stadium. numberOfMaxFans and numberOfMaxSeats are different because not every seat has to be filled
     * with a person holding a seasonPass. It is usual to have a big part of seats open for seasonPasses and a little part only open for one-match tickets
     * -numberOfSympathizer :Current number of Sympathizers They have no seat , but have benefits of SeasonPass Holders(Discounts, special treatment in giveaways, special prizes for one-match tickets)
     * -sympathizerFee : Prize to be a Sympathizer
     * -numberOfZones : Number of Zones of the stadium. Normally used because different zones have different prizes and it is normal to try to save some
     * number of seats free in different zones for one-match tickets.
     * -seasonStages : Enum that track the stages of the season
     */
    uint256 private seasonNumber;

    uint256 private numberOfMaxFans;
    uint256 private numberOfCurrentFans;

    uint256 private numberOfMaxSeats;

    uint256 private numberOfSympathizer;
    uint256 private sympathizerFee;

    uint256 private numberOfZones;
    Stages private seasonStages;

    /**
     * @dev  SYMPATHIZER_OFFSET : If we start giving the sympathizers the ids just after numberOfMaxFans, it can be a problem if in the future we make greater this number
     * Example. 12 000 max fans 1st season . 1 000 are sympathizers and we give them ids from 12001 to 13 000.
     * Then if in 2nd season we make the max fans 15 000 , when giving the iDs to new fans , the new 3000 fans will clash Ids with sympathizer (fan 12 001 wil have same id as sympathizer 1)
     * Therefore we add an offset to make it barely impossible to add as many new fans
     *
     */
    uint256 private constant SYMPATHIZER_OFFSET = 1000000;

    /**
     * @dev  MAPPINGS
     * -s_MaxAvailableSeats : Stores the information of the available seats per Zone. Could be modified to be just an array instead of a mapping for gas optimization purposes
     * -s_SeasonPasses : Stores the information of the seasonPasses for every fan
     * -s_Seats : Stores the information of every Seat
     */
    mapping(uint256 zone => uint256 availableSeats) s_MaxAvailableSeats;
    mapping(address fan => SeasonPass) s_SeasonPasses;
    mapping(uint256 seatId => Seat) s_Seats;

    /**
     *
     * onlyInGivenStage : Ensures that the functions are called in the correct stage . This helps with integrity issues
     */
    modifier onlyInGivenStage(Stages stage_, bool possibleAfter_) {
        if ((seasonStages < stage_ && possibleAfter_) || seasonStages != stage_) {
            revert SeasonPass_CalledInWrongStage();
        }
        _;
    }

    /**
     *
     * @dev : Setting up the contract with the proper variables explained above and setting the Stage in "RENEWALS"
     */
    constructor(
        uint256 seasonNumber_,
        uint256 numberOfMaxFans_,
        uint256 numberOfMaxSeats_,
        uint256 numberOfZones_,
        uint256 sympathizerFee_
    ) Ownable(msg.sender) {
        seasonNumber = seasonNumber_;
        numberOfMaxFans = numberOfMaxFans_;
        numberOfMaxSeats = numberOfMaxSeats_;
        numberOfZones = numberOfZones_;
        sympathizerFee = sympathizerFee_;
        seasonStages = Stages.RENEWALS;
    }

    /**
     *
     * @param seatInfo Contains the Info of the Seats in order to be modified
     * @param isDeleting If the intention is deleting those seats, must be a `true`
     * @param isFirstTime If it´s the first time calling the function, must be `true`
     *
     * @dev Intended to be called sporadically, when new Seats are added deleted or modified due to renovations
     *
     */
    function setSeatInfo(Seat[] memory seatInfo, bool isDeleting, bool isFirstTime) external onlyOwner {
        uint256 oldNumberOfMaxSeats = numberOfMaxSeats;
        if (isDeleting == true) {
            uint256 deletedSeats;
            for (uint256 i; i < seatInfo.length; i++) {
                if (s_Seats[seatInfo[i].seatId].rowSeatNumber != 0) {
                    s_Seats[seatInfo[i].seatId].rowSeatNumber = 0;
                    s_Seats[seatInfo[i].seatId].seatOwner = address(0);
                    deletedSeats++;
                }
            }
            numberOfMaxSeats -= deletedSeats;
        } else {
            uint256 addedSeats;
            for (uint256 i; i < seatInfo.length; i++) {
                if (s_Seats[seatInfo[i].seatId].rowSeatNumber == 0) {
                    addedSeats++;
                }
                s_Seats[seatInfo[i].seatId] = seatInfo[i];
                s_SeasonPasses[seatInfo[i].seatOwner].seatId = seatInfo[i].seatId;
            }
            if (!isFirstTime) {
                numberOfMaxSeats += addedSeats;
            }
        }
        emit SeasonPass_NumberOfSeatsModified(oldNumberOfMaxSeats, numberOfMaxSeats);
    }

    /**
     *
     * @param variationOfAvailableSeats : Number of seats that were added (in positive) or deleted (in negative) for every zone.
     * @dev : Called every time `setSeatInfo` is called in order to translate the information of the changed seats into the mapping of available
     * seats per zone
     */
    function modifyAvailableSeats(int256[] memory variationOfAvailableSeats) external onlyOwner {
        for (uint256 i = 0; i < variationOfAvailableSeats.length; i++) {
            int256 endResult = int256(s_MaxAvailableSeats[i]) + variationOfAvailableSeats[i];
            if (endResult >= 0) {
                s_MaxAvailableSeats[i] = uint256(endResult);
            }
        }
        emit SeasonPass_UpdatedSeatAvailability();
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// STAGE MANAGEMENT ////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     *
     * @dev : Used once a year to start the new Season! Insert same values as last season if there is no difference with those variables
     * @param numberOfMaxFans_ : New amount of Fans allowed to get a SeasonPass
     * @param numberOfMaxSeats_ : New amount of Seats that are available for one-match tickets and seasonPasses
     * @param numberOfZones_ : New number of zones if they were modified
     */
    function startNewSeason(uint256 numberOfMaxFans_, uint256 numberOfMaxSeats_, uint256 numberOfZones_)
        external
        onlyOwner
    {
        seasonNumber++;
        numberOfMaxFans = numberOfMaxFans_;
        numberOfMaxSeats = numberOfMaxSeats_;
        numberOfZones = numberOfZones_;
        seasonStages = Stages.RENEWALS;
        emit SeasonPass_NewSeasonStarted(numberOfMaxFans, numberOfMaxSeats, numberOfZones_);
    }

    /**
     * @dev : Used every time the Stage of the season advances. Called 3 or 4 times a season
     */
    function advanceStage() external onlyOwner {
        if (seasonStages == Stages.REGULAR_SEASON) {
            revert SeasonPass_CalledInWrongStage();
        }
        seasonStages = Stages(uint256(seasonStages) + 1);
        emit SeasonPass_AdvancedTheStage(seasonStages);
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// RENEWALS ////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev : Store the updated order of users of the seasonPass. Once a year normally.
     * Just before advancing to next stage
     * @param fans_ : users that renewed the seasonPass in order of new SeasonPassId
     *
     */
    function changeNumberOfSeasonIds(address[] memory fans_)
        external
        onlyOwner
        onlyInGivenStage(Stages.RENEWALS, false)
    {
        if (fans_.length > numberOfMaxFans) {
            revert SeasonPass_MoreSeasonPassesThanExpected();
        }
        for (uint256 i; i < fans_.length; i++) {
            s_SeasonPasses[fans_[i]].idOfSeasonPass = i + 1;
            s_SeasonPasses[fans_[i]].seasonNumber = seasonNumber;
        }
        numberOfCurrentFans = fans_.length;
        emit SeasonPass_UpdatedNumberOfSeasonPassIds();
    }
    /**
     * @dev : Delete the users that did not renew this season. Called after `changeNumberOfSeasonIds`. Just after, `advanceStage` should be called
     *
     * @param fans_ : users that did not renew the seasonPass in order of new SeasonPassId
     */

    function deleteNumberOfSeasonIds(address[] memory fans_)
        external
        onlyOwner
        onlyInGivenStage(Stages.RENEWALS, false)
    {
        uint256 deleted;
        for (uint256 i = 0; i < fans_.length; i++) {
            if (s_SeasonPasses[fans_[i]].idOfSeasonPass != 0) {
                s_SeasonPasses[fans_[i]].idOfSeasonPass = 0;
                s_SeasonPasses[fans_[i]].seatId = 0;
                deleted++;
            }
        }
        numberOfCurrentFans -= deleted;
        emit SeasonPass_DeletedOldNumberOfSeasonPassIds();
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// SEAT_CHANGES ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev : Function that allows to swap the seat with a free one
     * @param fanAddress_ : User that wants to change the seat
     * @param oldSeatId_  : Old SeatId of the user
     * @param oldZoneId_  : ZoneId of the seat wanting to be changed
     * @param newSeatId_  : SeatId of the new seat
     * @param newZoneId_  : ZoneId of the new seat
     */
    function changeSeat(
        address fanAddress_,
        uint256 oldSeatId_,
        uint256 oldZoneId_,
        uint256 newSeatId_,
        uint256 newZoneId_
    ) external onlyOwner onlyInGivenStage(Stages.SEAT_CHANGES, true) {
        if (s_SeasonPasses[fanAddress_].seatId == 0) {
            revert SeasonPass_FanHasNoSeasonPass();
        }
        if (s_Seats[newSeatId_].seatOwner != address(0)) {
            revert SeasonPass_SeatIsNotFree();
        }
        if (s_MaxAvailableSeats[newZoneId_] == 0) {
            revert SeasonPass_MaxSeatsInZone();
        }
        if (
            s_Seats[s_SeasonPasses[fanAddress_].seatId].zone != oldZoneId_
                || s_SeasonPasses[fanAddress_].seatId != oldSeatId_
        ) {
            revert SeasonPass_WrongInformationGiven();
        }
        s_Seats[oldSeatId_].seatOwner = address(0);
        s_MaxAvailableSeats[oldZoneId_]++;
        s_Seats[newSeatId_].seatOwner = fanAddress_;
        s_MaxAvailableSeats[newZoneId_]--;
        s_SeasonPasses[fanAddress_].seatId = newSeatId_;
        emit SeasonPass_ChangeSeat(fanAddress_);
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// NEW_FANS ////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    /**
     * @dev : Fans decide to pay a little less than a seasonPass and dont have an assigned seat, but mantain benefits of SeasonPass Holders(Discounts, special treatment in giveaways, special prizes for one-match tickets...)
     * SeasonPass holders are not allowed to be (All benefits of sympathizers are also for seasonPass holders)
     */
    function becomeSympathizer() external payable onlyInGivenStage(Stages.NEW_FANS, true) {
        if (s_SeasonPasses[msg.sender].seatId != 0 || s_SeasonPasses[msg.sender].idOfSeasonPass != 0) {
            revert SeasonPass_FanAddedBefore();
        }

        if (msg.value < sympathizerFee) {
            revert SeasonPass_NotEnoughETHSent();
        }

        s_SeasonPasses[msg.sender].idOfSeasonPass = seasonNumber * SYMPATHIZER_OFFSET + numberOfSympathizer + 1;
        numberOfSympathizer++;
        emit SeasonPass_NewSympathizer(msg.sender, numberOfSympathizer);
    }

    /**
     * @dev : Function used to add a fan into the system (Buys a SeasonPass).
     * The purchase has to be done in the app or webpage because different zones, ages, social situation makes the price fluctuate
     * @param fan_ : address of the new fan added
     * @param seatId_ : Id of the seat chosen by the user for the new seasonPass
     * @param zone_  : Zone of the seat
     */
    function addNewFan(address fan_, uint256 seatId_, uint256 zone_)
        external
        onlyOwner
        onlyInGivenStage(Stages.NEW_FANS, true)
    {
        if (s_SeasonPasses[fan_].seatId != 0) {
            revert SeasonPass_FanAddedBefore();
        }
        if (s_Seats[seatId_].seatOwner != address(0)) {
            revert SeasonPass_SeatIsNotFree();
        }
        if (s_MaxAvailableSeats[zone_] == 0) {
            revert SeasonPass_MaxSeatsInZone();
        }
        if (numberOfCurrentFans >= numberOfMaxFans) {
            revert SeasonPass_MaximumFansAdded();
        }

        s_Seats[seatId_].seatOwner = fan_;

        SeasonPass memory newSeasonPass;
        newSeasonPass.idOfSeasonPass = numberOfCurrentFans + 1;
        newSeasonPass.seatId = seatId_;
        newSeasonPass.seasonNumber = seasonNumber;

        s_SeasonPasses[fan_] = newSeasonPass;
        s_MaxAvailableSeats[zone_]--;
        numberOfCurrentFans++;
        emit SeasonPass_NewFan(fan_, numberOfCurrentFans);
    }

    /**
     * @dev : Function used for attending the match. Called many times every matchDay
     * @param match_ : Number of the match you are atending
     * @param fan_ : Address of the fan atending
     */
    function attendMatch(uint256 match_, address fan_) external onlyOwner {
        bool[500] memory aux = s_SeasonPasses[fan_].matchesGoneToStadium;
        uint256 season = s_SeasonPasses[fan_].seasonNumber;
        if (season != seasonNumber) {
            revert SeasonPass_SeasonPassNotRenewed();
        }
        if (aux[match_]) {
            revert SeasonPass_MatchEnteredBefore();
        }
        s_SeasonPasses[fan_].matchesGoneToStadium[match_] = true;
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// SETTERS /////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    function setSympathizerFee(uint256 newfee_) external onlyOwner {
        uint256 oldSympathizerFee = sympathizerFee;
        sympathizerFee = newfee_;
        emit SeasonPass_UpdatedSympathizerFee(oldSympathizerFee, sympathizerFee);
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// GETTERS /////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    function transferMoney() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        if (!success) {
            revert SeasonPass_TransferFailed();
        }
    }

    function getNumberOfSympathizer() public view returns (uint256) {
        return numberOfSympathizer;
    }

    function getSeasonNumber() public view returns (uint256) {
        return seasonNumber;
    }

    function getSympathizerFee() public view returns (uint256) {
        return sympathizerFee;
    }

    function getNumberOfMaxFans() public view returns (uint256) {
        return numberOfMaxFans;
    }

    function getNumberOfCurrentFans() public view returns (uint256) {
        return numberOfCurrentFans;
    }

    function getNumberOfMaxSeats() public view returns (uint256) {
        return numberOfMaxSeats;
    }

    function getNumberOfZones() public view returns (uint256) {
        return numberOfZones;
    }

    function getSeasonStages() public view returns (Stages) {
        return seasonStages;
    }

    function getMaxAvailableSeats(uint256 zone) public view returns (uint256) {
        return s_MaxAvailableSeats[zone];
    }

    function getSeasonPass(address fan) public view returns (SeasonPass memory) {
        return s_SeasonPasses[fan];
    }

    function getSeat(uint256 seatId) public view returns (Seat memory) {
        return s_Seats[seatId];
    }

    function getSeatOwner(uint256 seatId) public view returns (address) {
        return s_Seats[seatId].seatOwner;
    }

    function getSeatOfFan(address fan_) public view returns (uint256) {
        return s_SeasonPasses[fan_].seatId;
    }
}
