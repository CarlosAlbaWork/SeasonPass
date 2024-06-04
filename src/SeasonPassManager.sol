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
    error SeasonPass_MoreSeasonPassesThanExpected(
        uint256 length,
        uint256 maxFans
    );
    error SeasonPass_NotOwnerOfSeasonPass();
    error SeasonPass_NotEnoughETHSent();

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// STRUCTS /////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    struct Seat {
        address seatOwner;
        uint256 zone;
        uint256 row;
        uint256 seatId;
        uint256 rowSeatNumber;
    }

    struct SeasonPass {
        uint256 idOfSeasonPass;
        uint256 seatId;
        bool[] matchesGoneToStadium;
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// ENUMS ///////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    enum Stages {
        PRE_CAMPAIGN,
        RENEWALS,
        SEAT_CHANGES,
        NEW_FANS,
        REGULAR_SEASON
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// EVENTS //////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    event SeasonPass_NumberOfSeatsModified(
        uint256 indexed oldnumberOfMaxSeats,
        uint256 indexed newnumberOfMaxSeats
    );
    event SeasonPass_UpdatedSeatAvailability();
    event SeasonPass_UpdatedSympathizerFee(
        uint256 indexed oldSympathizerFee,
        uint256 indexed newSympathizerFee
    );
    event SeasonPass_NewSeasonStarted(
        uint256 indexed numberOfMaxFans_,
        uint256 indexed numberOfMaxSeats_,
        uint256 indexed numberOfZones_
    );
    event SeasonPass_AdvancedTheStage(Stages newstage);
    event SeasonPass_UpdatedNumberOfSeasonPassIds();
    event SeasonPass_DeletedOldNumberOfSeasonPassIds();
    event SeasonPass_SetSeatAvailability();
    event SeasonPass_NewSympathizer(
        address indexed sympathizer,
        uint256 indexed numberOfSympathizers
    );
    event SeasonPass_NewFan(address indexed fan, uint256 indexed numberOfFans);
    event SeasonPass_ChangeSeat(address indexed fan);

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// VARIABLES ///////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    uint256 private seasonNumber;

    uint256 private numberOfMaxFans;
    uint256 private numberOfCurrentFans;

    uint256 private numberOfMaxSeats;

    uint256 private numberOfSympathizer; //They have no seat , but have benefits of SeasonPass Holders
    uint256 private sympathizerFee;

    //If we start giving the sympathizers the ids just after numberOfMaxFans, it can be a problem
    // if in the future we make greater this number
    //Example. 12 000 max fans 1st season . 1 000 are sympathizers and we give them ids from 12001 to 13 000
    //Then if in 2nd season we make the max fans 15 000 , when giving the iDs to new fans , the new 3000 fans will clash
    //Ids with sympathizer (fan 12 001 wil have same id as sympathizer 1)
    //Therefore we add an offset to make it barely impossible to add as many new fans

    uint256 private constant SYMPATHIZER_OFFSET = 1000000;

    uint256 private numberOfZones;
    Stages private seasonStages;

    // Some seats are reserved to sell as one use tickets. Therefore there should be a mapping that controls that this number is never surpassed
    //Se puede usar para este primero un array
    mapping(uint256 zone => uint256 availableSeats) s_MaxAvailableSeats;
    mapping(address fan => SeasonPass) s_SeasonPasses;
    mapping(uint256 seatId => Seat) s_Seats;

    modifier onlyInGivenStage(Stages stage_, bool possibleAfter_) {
        if (
            (seasonStages < stage_ && possibleAfter_) || seasonStages != stage_
        ) {
            revert SeasonPass_CalledInWrongStage();
        }
        _;
    }

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

    //Function to add or delete seats in case of renovation in stadium or other situations
    // If isDeleting == true: Just delete the seats
    //else adding seats or information
    function setSeatInfo(
        Seat[] memory seatInfo,
        bool isDeleting
    ) external onlyOwner {
        uint256 oldNumberOfMaxSeats = numberOfMaxSeats;
        if (isDeleting == true) {
            for (uint i; i < seatInfo.length; i++) {
                s_Seats[seatInfo[i].seatId].rowSeatNumber = 0;
            }
            numberOfMaxSeats -= seatInfo.length;
        } else {
            for (uint i; i < seatInfo.length; i++) {
                s_Seats[seatInfo[i].seatId] = seatInfo[i];
            }
            if (seatInfo.length != numberOfMaxSeats) {
                numberOfMaxSeats += seatInfo.length;
            }
        }
        emit SeasonPass_NumberOfSeatsModified(
            oldNumberOfMaxSeats,
            numberOfMaxSeats
        );
    }

    //Always after setSeatInfo, in order to mantain integrity with the mapping of available seats

    function modifyAvailableSeats(
        int256[] memory variationOfAvailableSeats
    ) external onlyOwner {
        for (uint i = 0; i < variationOfAvailableSeats.length; i++) {
            s_MaxAvailableSeats[i] = uint256(
                int256(s_MaxAvailableSeats[i]) + variationOfAvailableSeats[i]
            );
        }
        emit SeasonPass_UpdatedSeatAvailability();
    }

    function setSympathizerFee(uint256 newfee_) external onlyOwner {
        uint256 oldSympathizerFee = sympathizerFee;
        sympathizerFee = newfee_;
        emit SeasonPass_UpdatedSympathizerFee(
            oldSympathizerFee,
            sympathizerFee
        );
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// STAGE MANAGEMENT ////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    function startNewSeason(
        uint256 numberOfMaxFans_,
        uint256 numberOfMaxSeats_,
        uint256 numberOfZones_
    ) external onlyOwner {
        seasonNumber++;
        numberOfMaxFans = numberOfMaxFans_;
        numberOfMaxSeats = numberOfMaxSeats_;
        numberOfZones = numberOfZones_;
        seasonStages = Stages.RENEWALS;
        emit SeasonPass_NewSeasonStarted(
            numberOfMaxFans,
            numberOfMaxSeats,
            numberOfZones_
        );
    }

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

    // array of addresses of fans in order
    //Once a year normally

    function changeNumberOfSeasonIds(
        address[] memory fans_
    ) external onlyOwner onlyInGivenStage(Stages.RENEWALS, false) {
        if (fans_.length > numberOfMaxFans) {
            revert SeasonPass_MoreSeasonPassesThanExpected(
                fans_.length,
                numberOfMaxFans
            );
        }
        for (uint i; i < fans_.length; i++) {
            s_SeasonPasses[fans_[i]].idOfSeasonPass = i + 1;
        }
        numberOfCurrentFans = fans_.length;
        emit SeasonPass_UpdatedNumberOfSeasonPassIds();
    }

    function deleteNumberOfSeasonIds(
        address[] memory fans_
    ) external onlyOwner onlyInGivenStage(Stages.RENEWALS, false) {
        for (uint i = 0; i < fans_.length; i++) {
            s_SeasonPasses[fans_[i]].idOfSeasonPass = 0;
            s_SeasonPasses[fans_[i]].seatId = 0;
        }
        emit SeasonPass_DeletedOldNumberOfSeasonPassIds();
    }

    //Different function to deleteNumberOfSeasonIds to count zone available seats
    function setSeatAvailability(
        uint256[][] memory freeSeatIds_ //like a mapping(uint256 zone => uint256 availableSeats)
    ) external onlyOwner onlyInGivenStage(Stages.RENEWALS, false) {
        for (uint j; j < numberOfZones; j++) {
            for (uint i = 0; i < freeSeatIds_[j].length; i++) {
                if (s_Seats[freeSeatIds_[j][i]].seatOwner != address(0)) {
                    s_Seats[freeSeatIds_[j][i]].seatOwner = address(0);
                }
            }
            s_MaxAvailableSeats[j] = freeSeatIds_[j].length;
            emit SeasonPass_SetSeatAvailability();
        }
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// SEAT_CHANGES ////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

    //It will be executed in any other stage that is not RENEWALS

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
            s_Seats[s_SeasonPasses[fanAddress_].seatId].zone != oldZoneId_ ||
            s_SeasonPasses[fanAddress_].seatId != oldSeatId_
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

    function becomeSympathizer()
        external
        payable
        onlyInGivenStage(Stages.NEW_FANS, true)
    {
        if (
            s_SeasonPasses[msg.sender].seatId != 0 ||
            s_SeasonPasses[msg.sender].idOfSeasonPass != 0
        ) {
            revert SeasonPass_FanAddedBefore();
        }

        if (msg.value < sympathizerFee) {
            revert SeasonPass_NotEnoughETHSent();
        }

        s_SeasonPasses[msg.sender].idOfSeasonPass =
            seasonNumber *
            SYMPATHIZER_OFFSET +
            numberOfSympathizer +
            1;
        numberOfSympathizer++;
        emit SeasonPass_NewSympathizer(msg.sender, numberOfSympathizer);
    }

    function addNewFan(
        address fan_,
        uint256 seatId_,
        uint256 zone_
    ) external onlyOwner onlyInGivenStage(Stages.NEW_FANS, true) {
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
        newSeasonPass.idOfSeasonPass = numberOfCurrentFans;
        newSeasonPass.seatId = seatId_;

        s_SeasonPasses[fan_] = newSeasonPass;
        s_MaxAvailableSeats[zone_]--;
        numberOfCurrentFans++;
        emit SeasonPass_NewFan(fan_, numberOfCurrentFans);
    }

    //Si es la primera jornada, es posible que con un carnet se entre varias veces por como está hecho el código. Hay que poner un check en el Front
    function attendMatch(
        uint256 match_,
        address fan_
    ) external onlyOwner returns (bool) {
        bool[] memory aux = s_SeasonPasses[fan_].matchesGoneToStadium;
        if (!aux[match_] || (match_ == 1 && aux[0] != isEven(seasonNumber))) {
            if (match_ == 1) {
                aux[1] = true;
                aux[0] = isEven(seasonNumber);
                s_SeasonPasses[fan_].matchesGoneToStadium = aux;
            } else {
                s_SeasonPasses[fan_].matchesGoneToStadium[match_] = true;
            }
            return true;
        }
        return false;
    }

    function isEven(uint256 seasonNumber_) public pure returns (bool) {
        if (seasonNumber_ % 2 == 0) {
            return true;
        }
        return false;
    }

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////// GETTERS /////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

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

    // Getter function for s_MaxAvailableSeats
    function getMaxAvailableSeats(uint256 zone) public view returns (uint256) {
        return s_MaxAvailableSeats[zone];
    }

    // Getter function for s_SeasonPasses
    function getSeasonPass(
        address fan
    ) public view returns (SeasonPass memory) {
        return s_SeasonPasses[fan];
    }

    // Getter function for s_Seats
    function getSeat(uint256 seatId) public view returns (Seat memory) {
        return s_Seats[seatId];
    }

    function getSeatOwner(uint256 seatId) public view returns (address) {
        return s_Seats[seatId].seatOwner;
    }

    function getSeatOfFan(address fan_) public view returns (uint256) {
        //MIght have to restrict to msg.sender == fan_ or Owner
        return s_SeasonPasses[fan_].seatId;
    }
}
