// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SeasonPassManager} from "../src/contracts/SeasonPassManager.sol";
import {DeploySeasonPassManager} from "../script/DeploySeasonPassManager.s.sol";

contract SeasonPassManagerTest is Test {
    SeasonPassManager seasonPassManager;
    uint256 constant FAN_1_ID = 1;
    uint256 constant FAN_2_ID = 2;
    uint256 constant FAN_3_ID = 3;
    uint256 constant SEAT_1_ID = 1;
    uint256 constant SEAT_2_ID = 2;
    uint256 constant ZONE_1_ID = 1;
    uint256 constant ZONE_2_ID = 2;

    uint256 constant SEASON_NUMBER = 1;
    uint256 constant NUMBER_OF_MAX_FANS = 100;
    uint256 constant MAX_SEATS = 500;
    uint256 constant NUMBER_OF_ZONES = 10;
    uint256 constant SYMPATHYZER_FEE = 1 ether;

    modifier addFansAndSeats() {
        vm.startPrank(seasonPassManager.owner());
        address[] memory fans = new address[](3);
        fans[0] = address(0x1);
        fans[1] = address(0x2);
        fans[2] = address(0x3);
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](3);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seasonPassManager.changeNumberOfSeasonIds(fans);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        int256[] memory variation = new int256[](10);
        variation[1] = 4;
        variation[2] = 6;
        variation[3] = 9;
        seasonPassManager.modifyAvailableSeats(variation);
        _;
    }

    function setUp() public {
        DeploySeasonPassManager deployer = new DeploySeasonPassManager();
        (seasonPassManager,) = deployer.run();
    }

    function beforeEach() public {
        seasonPassManager =
            new SeasonPassManager(SEASON_NUMBER, NUMBER_OF_MAX_FANS, MAX_SEATS, NUMBER_OF_ZONES, SYMPATHYZER_FEE);
    }

    /////////////////////////////////////
    ///// Test Constructor //////////////
    /////////////////////////////////////

    function testConstructor() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(seasonPassManager.getSeasonNumber(), SEASON_NUMBER, "Maximum fans should be 200");
        assertEq(seasonPassManager.getNumberOfMaxFans(), NUMBER_OF_MAX_FANS, "Maximum fans should be 200");
        assertEq(seasonPassManager.getNumberOfMaxSeats(), MAX_SEATS, "Maximum seats should be 500");
        assertEq(seasonPassManager.getNumberOfZones(), NUMBER_OF_ZONES, "Number of zones should be 10");
        assertEq(seasonPassManager.getSympathizerFee(), SYMPATHYZER_FEE, "Number of zones should be 1 ether");

        assertEq(
            uint256(seasonPassManager.getSeasonStages()),
            uint256(SeasonPassManager.Stages.RENEWALS),
            "Season stage should be RENEWALS"
        );
    }

    /////////////////////////////////////
    ///// Test StartNewSeason ///////////
    /////////////////////////////////////

    function testStartNewSeason() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.startNewSeason(1000, 1000, 1000);
        assertEq(seasonPassManager.getSeasonNumber(), 2);
        assertEq(seasonPassManager.getNumberOfMaxFans(), 1000, "Maximum fans should be 1000");
        assertEq(seasonPassManager.getNumberOfMaxSeats(), 1000, "Maximum seats should be 1000");
        assertEq(seasonPassManager.getNumberOfZones(), 1000, "Number of zones should be 1000");
        assertEq(
            uint256(seasonPassManager.getSeasonStages()),
            uint256(SeasonPassManager.Stages.RENEWALS),
            "Season stage should be RENEWALS"
        );
    }

    /////////////////////////////////////
    ///// Test advanceStage ///////////
    /////////////////////////////////////

    // Test case 2: Test advanceStage function
    function testAdvanceStage() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.advanceStage();
        assertEq(
            uint256(seasonPassManager.getSeasonStages()),
            uint256(SeasonPassManager.Stages.SEAT_CHANGES),
            "Season stage should be SEAT_CHANGES"
        );
        seasonPassManager.advanceStage();
        assertEq(
            uint256(seasonPassManager.getSeasonStages()),
            uint256(SeasonPassManager.Stages.NEW_FANS),
            "Season stage should be NEW_FANS"
        );
        seasonPassManager.advanceStage();
        assertEq(
            uint256(seasonPassManager.getSeasonStages()),
            uint256(SeasonPassManager.Stages.REGULAR_SEASON),
            "Season stage should be REGULAR_SEASON"
        );
        vm.expectRevert(SeasonPassManager.SeasonPass_CalledInWrongStage.selector);
        seasonPassManager.advanceStage();
    }

    /////////////////////////////////////
    ///// Test SetSeatInfo //////////////
    /////////////////////////////////////

    function testSetSeatInfoDeleting() public {
        vm.startPrank(seasonPassManager.owner());
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](3);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        seasonPassManager.setSeatInfo(seatIds, true, false);
        assertEq(seasonPassManager.getNumberOfMaxSeats(), MAX_SEATS - 3, "Should be 497");
    }

    function testSetSeatInfoModifyOldSeats() public {
        vm.startPrank(seasonPassManager.owner());

        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](3);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 4, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 5, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 6, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, false);
        assertEq(seasonPassManager.getNumberOfMaxSeats(), MAX_SEATS, "Should be 500");
        assertEq(seasonPassManager.getSeat(1).zone, 4, "Should be 4");
        assertEq(seasonPassManager.getSeat(2).zone, 5, "Should be 5");
        assertEq(seasonPassManager.getSeat(3).zone, 6, "Should be 6");
    }

    function testSetSeatInfoNewSeats() public {
        vm.startPrank(seasonPassManager.owner());
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](3);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        seatIds[0] = SeasonPassManager.Seat(4, address(0x1), 4, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(5, address(0x2), 5, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(6, address(0x3), 6, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, false);
        assertEq(seasonPassManager.getNumberOfMaxSeats(), MAX_SEATS + 3, "Should be 503");
    }

    function testSetSeatInfoMixNewAndModifiedSeats() public {
        vm.startPrank(seasonPassManager.owner());
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](3);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        SeasonPassManager.Seat[] memory seatIdsMix = new SeasonPassManager.Seat[](6);
        seatIdsMix[0] = SeasonPassManager.Seat(1, address(0x1), 4, 1, 1);
        seatIdsMix[1] = SeasonPassManager.Seat(2, address(0x2), 5, 2, 2);
        seatIdsMix[2] = SeasonPassManager.Seat(3, address(0x3), 6, 3, 3);
        seatIdsMix[3] = SeasonPassManager.Seat(4, address(0x1), 4, 4, 1);
        seatIdsMix[4] = SeasonPassManager.Seat(5, address(0x2), 5, 5, 2);
        seatIdsMix[5] = SeasonPassManager.Seat(6, address(0x3), 6, 6, 3);
        seasonPassManager.setSeatInfo(seatIdsMix, false, false);
        assertEq(seasonPassManager.getNumberOfMaxSeats(), MAX_SEATS + 3, "Should be 503");
    }

    /////////////////////////////////////
    ///// Test modifyAvailableSeats /////
    /////////////////////////////////////

    function testModifyAvalableSeatsNormal() public {
        vm.startPrank(seasonPassManager.owner());
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](3);
        int256[] memory variation = new int256[](10);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 3, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        variation[1] = 1;
        variation[2] = 1;
        variation[3] = 1;
        seasonPassManager.modifyAvailableSeats(variation);
        seatIds[0] = SeasonPassManager.Seat(1, address(0x1), 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(2, address(0x2), 1, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(3, address(0x3), 1, 3, 3);
        seasonPassManager.setSeatInfo(seatIds, false, true);
        variation[1] = 2;
        variation[2] = -1;
        variation[3] = -1;
        seasonPassManager.modifyAvailableSeats(variation);
        assertEq(seasonPassManager.getMaxAvailableSeats(1), 3, "Should be 3");
        assertEq(seasonPassManager.getMaxAvailableSeats(2), 0, "Should be 0");
        assertEq(seasonPassManager.getMaxAvailableSeats(3), 0, "Should be 0");
        variation[1] = 0;
        variation[2] = -1;
        variation[3] = 0;
        seasonPassManager.modifyAvailableSeats(variation);
        assertEq(seasonPassManager.getMaxAvailableSeats(1), 3, "Should be 3");
        assertEq(seasonPassManager.getMaxAvailableSeats(2), 0, "Should be 0");
        assertEq(seasonPassManager.getMaxAvailableSeats(3), 0, "Should be 0");
    }

    /////////////////////////////////////
    ///// Test changeNumberOfSeasonIds /////
    /////////////////////////////////////

    function testChangeNumberOfSeasonIds() public addFansAndSeats {
        assertEq(seasonPassManager.getNumberOfCurrentFans(), 3, "Number of current fans should be 3");
        assertEq(seasonPassManager.getSeasonPass(address(0x1)).idOfSeasonPass, 1, "Id Should be 1");
        assertEq(seasonPassManager.getSeasonPass(address(0x2)).idOfSeasonPass, 2, "Id Should be 2");
        assertEq(seasonPassManager.getSeasonPass(address(0x3)).idOfSeasonPass, 3, "Id Should be 3");
        address[] memory newFans = new address[](4);
        newFans[0] = address(0x3);
        newFans[1] = address(0x1);
        newFans[2] = address(0x2);
        newFans[3] = address(0x4);
        seasonPassManager.changeNumberOfSeasonIds(newFans);
        assertEq(seasonPassManager.getNumberOfCurrentFans(), 4, "Number of current fans should be 4");
        assertEq(seasonPassManager.getSeasonPass(address(0x1)).idOfSeasonPass, 2, "Should be 2");
        assertEq(seasonPassManager.getSeasonPass(address(0x2)).idOfSeasonPass, 3, "Should be 3");
        assertEq(seasonPassManager.getSeasonPass(address(0x3)).idOfSeasonPass, 1, "Should be 1");
        assertEq(seasonPassManager.getSeasonPass(address(0x4)).idOfSeasonPass, 4, "Should be 4");
    }

    function testChangeNumberOfSeasonIdsReverts() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.startNewSeason(2, 1000, 1000);
        address[] memory fans = new address[](3);
        fans[0] = address(0x1);
        fans[1] = address(0x2);
        fans[2] = address(0x3);
        vm.expectRevert(SeasonPassManager.SeasonPass_MoreSeasonPassesThanExpected.selector);
        seasonPassManager.changeNumberOfSeasonIds(fans);
    }

    /////////////////////////////////////
    ///// Test deleteNumberOfSeasonIds /////
    /////////////////////////////////////

    function testDeleteNumberOfSeasonIds() public {
        vm.startPrank(seasonPassManager.owner());

        address[] memory fans = new address[](3);
        fans[0] = address(0x1);
        fans[1] = address(0x2);
        fans[2] = address(0x3);
        seasonPassManager.changeNumberOfSeasonIds(fans);
        address[] memory deletedFans = new address[](4);
        deletedFans[0] = address(0x1);
        deletedFans[1] = address(0x2);
        deletedFans[2] = address(0x4);
        seasonPassManager.deleteNumberOfSeasonIds(deletedFans);
        assertEq(seasonPassManager.getNumberOfCurrentFans(), 1, "Number of current fans should be 1");
        assertEq(seasonPassManager.getSeasonPass(address(0x1)).idOfSeasonPass, 0, "Should be 0");
        assertEq(seasonPassManager.getSeasonPass(address(0x2)).idOfSeasonPass, 0, "Should be 0");
        assertEq(seasonPassManager.getSeasonPass(address(0x3)).idOfSeasonPass, 3, "Should be 3");
        assertEq(seasonPassManager.getSeasonPass(address(0x4)).idOfSeasonPass, 0, "Should be 0");
    }

    /////////////////////////////////////
    ///// Test changeSeat ///////////////
    /////////////////////////////////////

    function testChangeSeatRevertsIfNoSeasonPass() public addFansAndSeats {
        seasonPassManager.advanceStage();

        vm.expectRevert(SeasonPassManager.SeasonPass_FanHasNoSeasonPass.selector);
        seasonPassManager.changeSeat(address(0x4), SEAT_1_ID, ZONE_1_ID, SEAT_2_ID, ZONE_1_ID);
    }

    function testChangeSeatRevertsIfSeatNotFree() public addFansAndSeats {
        seasonPassManager.advanceStage();

        vm.expectRevert(SeasonPassManager.SeasonPass_SeatIsNotFree.selector);
        seasonPassManager.changeSeat(address(0x3), SEAT_1_ID, ZONE_1_ID, SEAT_2_ID, ZONE_1_ID);
    }

    function testChangeSeatRevertsIfMaxSeatsInZone() public addFansAndSeats {
        seasonPassManager.advanceStage();

        int256[] memory variation = new int256[](10);
        variation[1] = -int256(seasonPassManager.getMaxAvailableSeats(1));
        seasonPassManager.modifyAvailableSeats(variation);
        vm.expectRevert(SeasonPassManager.SeasonPass_MaxSeatsInZone.selector);
        seasonPassManager.changeSeat(address(0x3), 3, 3, 8, ZONE_1_ID);
    }

    function testChangeSeatRevertsIfWrongInformationGivenOldZone() public addFansAndSeats {
        seasonPassManager.advanceStage();
        vm.expectRevert(SeasonPassManager.SeasonPass_WrongInformationGiven.selector);
        seasonPassManager.changeSeat(address(0x3), 3, 2, 8, ZONE_1_ID);
    }

    function testChangeSeatRevertsIfWrongInformationGivenOldSeatID() public addFansAndSeats {
        seasonPassManager.advanceStage();
        vm.expectRevert(SeasonPassManager.SeasonPass_WrongInformationGiven.selector);
        seasonPassManager.changeSeat(address(0x3), 1, 3, 8, ZONE_1_ID);
    }

    function testChangeSeat() public addFansAndSeats {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.advanceStage();
        seasonPassManager.changeSeat(address(0x3), 3, 3, 8, ZONE_1_ID);
        assertEq(seasonPassManager.getSeat(3).seatOwner, address(0), "Seat 1 should be free after changing");
        assertEq(seasonPassManager.getSeat(8).seatOwner, address(0x3), "Seat 2 should be owned by fan 1 after changing");
    }

    /////////////////////////////////////
    ///// Test becomeSympathizer ///////////////
    /////////////////////////////////////

    function testbecomeSympathizerRevertsIfFan() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.deal(address(0x1), 4 ether);
        vm.stopPrank();
        vm.startPrank(address(0x1));
        vm.expectRevert(SeasonPassManager.SeasonPass_FanAddedBefore.selector);
        seasonPassManager.becomeSympathizer{value: 1 ether}();
    }

    function testbecomeSympathizerRevertsIfnotEnoughEth() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.deal(address(0x95), 4 ether);
        vm.stopPrank();
        vm.startPrank(address(0x95));
        vm.expectRevert(SeasonPassManager.SeasonPass_NotEnoughETHSent.selector);
        seasonPassManager.becomeSympathizer{value: 0.5 ether}();
    }

    function testbecomeSympathizer() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.deal(address(0x95), 4 ether);
        vm.stopPrank();
        vm.startPrank(address(0x95));
        seasonPassManager.becomeSympathizer{value: 1 ether}();
        assertEq(seasonPassManager.getNumberOfSympathizer(), 1);
        assertEq(seasonPassManager.getSeasonPass(address(0x95)).idOfSeasonPass, 1000001);
    }

    /////////////////////////////////////
    ///// Test addNewFan ///////////////
    /////////////////////////////////////

    function testaddNewFanRevertsAddedBefore() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.expectRevert(SeasonPassManager.SeasonPass_FanAddedBefore.selector);
        seasonPassManager.addNewFan(address(0x1), 1, 1);
    }

    function testaddNewFanRevertsSeatNotFree() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.expectRevert(SeasonPassManager.SeasonPass_SeatIsNotFree.selector);
        seasonPassManager.addNewFan(address(0x95), 1, 1);
    }

    function testaddNewFanRevertsMaxSeatsInZone() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        int256[] memory variation = new int256[](10);
        variation[1] = -int256(seasonPassManager.getMaxAvailableSeats(1));
        seasonPassManager.modifyAvailableSeats(variation);
        vm.expectRevert(SeasonPassManager.SeasonPass_MaxSeatsInZone.selector);
        seasonPassManager.addNewFan(address(0x95), 78, 1);
    }

    function testaddNewFanRevertsMaxFansAdded() public addFansAndSeats {
        seasonPassManager.startNewSeason(0, 1000, 1000);
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.expectRevert(SeasonPassManager.SeasonPass_MaximumFansAdded.selector);
        seasonPassManager.addNewFan(address(0x95), 78, 1);
    }

    function testaddNewFan() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        seasonPassManager.addNewFan(address(0x95), 78, 1);

        assertEq(
            seasonPassManager.getSeasonPass(address(0x95)).idOfSeasonPass, seasonPassManager.getNumberOfCurrentFans()
        );
    }

    /////////////////////////////////////
    ///// Test attendMatch ///////////////
    /////////////////////////////////////
    function testAttendMatchRevertsIfNotRenovated() public addFansAndSeats {
        seasonPassManager.startNewSeason(NUMBER_OF_MAX_FANS, 500, 500);
        vm.expectRevert(SeasonPassManager.SeasonPass_SeasonPassNotRenewed.selector);
        seasonPassManager.attendMatch(1, address(0x1));
    }

    function testAttendMatchRevertsIfEnteredBefore() public addFansAndSeats {
        seasonPassManager.attendMatch(1, address(0x1));
        vm.expectRevert(SeasonPassManager.SeasonPass_MatchEnteredBefore.selector);
        seasonPassManager.attendMatch(1, address(0x1));
    }

    function testAttendMatch() public addFansAndSeats {
        seasonPassManager.attendMatch(1, address(0x1));
        assertEq(seasonPassManager.getSeasonPass(address(0x1)).matchesGoneToStadium[1], true);
    }

    /////////////////////////////////////
    ///// Test setSympathizerFee ////////
    /////////////////////////////////////

    function testsetSympathizerFee() public addFansAndSeats {
        seasonPassManager.setSympathizerFee(2 ether);
        assertEq(seasonPassManager.getSympathizerFee(), 2 ether);
    }

    /////////////////////////////////////
    ///// Test GETTERS //////////////////
    /////////////////////////////////////

    // Test case 8: Test getSeasonNumber function
    function testGetSeasonNumber() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.startNewSeason(NUMBER_OF_MAX_FANS, 500, 500);
        seasonPassManager.startNewSeason(NUMBER_OF_MAX_FANS, 500, 500);
        seasonPassManager.startNewSeason(NUMBER_OF_MAX_FANS, 500, 500);
        assertEq(seasonPassManager.getSeasonNumber(), 4);
    }

    // Test case 9: Test getNumberOfMaxFans function
    function testGetNumberOfMaxFans() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(seasonPassManager.getNumberOfMaxFans(), NUMBER_OF_MAX_FANS);
    }

    // Test case 10: Test getNumberOfCurrentFans function
    function testGetNumberOfCurrentFans() public addFansAndSeats {
        vm.startPrank(seasonPassManager.owner());
        assertEq(seasonPassManager.getNumberOfCurrentFans(), 3);
    }

    // Test case 11: Test getNumberOfMaxSeats function
    function testGetNumberOfMaxSeats() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(seasonPassManager.getNumberOfMaxSeats(), MAX_SEATS);
        seasonPassManager.startNewSeason(NUMBER_OF_MAX_FANS, 250, 500);
        assertEq(seasonPassManager.getNumberOfMaxSeats(), 250);
    }

    // Test case 12: Test getNumberOfZones function
    function testGetNumberOfZones() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(seasonPassManager.getNumberOfZones(), NUMBER_OF_ZONES);
        seasonPassManager.startNewSeason(NUMBER_OF_MAX_FANS, 250, 500);
        assertEq(seasonPassManager.getNumberOfZones(), 500);
    }

    // Test case 13: Test getSeasonStages function
    function testGetSeasonStages() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            uint256(seasonPassManager.getSeasonStages()),
            uint256(SeasonPassManager.Stages.RENEWALS),
            "Season stage should be RENEWALS initially"
        );
    }

    function testgetNumberOfSympathizer() public addFansAndSeats {
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        vm.deal(address(0x95), 4 ether);
        vm.deal(address(0x1), 4 ether);
        vm.deal(address(0x75), 4 ether);
        vm.stopPrank();
        vm.prank(address(0x95));
        seasonPassManager.becomeSympathizer{value: 1 ether}();
        vm.startPrank(address(0x1));
        vm.expectRevert(SeasonPassManager.SeasonPass_FanAddedBefore.selector);
        seasonPassManager.becomeSympathizer{value: 1 ether}();
        vm.stopPrank();
        vm.prank(address(0x75));
        seasonPassManager.becomeSympathizer{value: 1 ether}();
        assertEq(seasonPassManager.getNumberOfSympathizer(), 2);
    }

    function testgetSympathizerFee() public addFansAndSeats {
        assertEq(seasonPassManager.getSympathizerFee(), 1 ether);
        seasonPassManager.setSympathizerFee(2 ether);
        assertEq(seasonPassManager.getSympathizerFee(), 2 ether);
    }

    function testgetMaxAvailableSeats() public addFansAndSeats {
        assertEq(seasonPassManager.getMaxAvailableSeats(1), 4);
        seasonPassManager.advanceStage();
        seasonPassManager.changeSeat(address(0x1), 1, 1, 6, 2);
        assertEq(seasonPassManager.getMaxAvailableSeats(1), 5);
        assertEq(seasonPassManager.getMaxAvailableSeats(2), 5);
    }

    function testgetSeatOwner() public addFansAndSeats {
        assertEq(seasonPassManager.getSeatOwner(1), address(0x1));
        seasonPassManager.advanceStage();
        seasonPassManager.changeSeat(address(0x1), 1, 1, 6, 2);
        assertEq(seasonPassManager.getSeatOwner(1), address(0));
        seasonPassManager.changeSeat(address(0x2), 2, 2, 1, 1);
        assertEq(seasonPassManager.getSeatOwner(1), address(0x2));
    }

    function testgetSeatOfFan() public addFansAndSeats {
        assertEq(seasonPassManager.getSeatOfFan(address(0x1)), 1, "assert 1");
        address[] memory deletefans = new address[](1);
        deletefans[0] = address(0x1);
        seasonPassManager.deleteNumberOfSeasonIds(deletefans);
        assertEq(seasonPassManager.getSeatOfFan(address(0x1)), 0, "assert 2");
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        seasonPassManager.addNewFan(address(0x1), 75, 1);
        assertEq(seasonPassManager.getSeatOfFan(address(0x1)), 75, "assert 3");
    }
}
