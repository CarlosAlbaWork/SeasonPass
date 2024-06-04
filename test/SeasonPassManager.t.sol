// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SeasonPassManager} from "../../src/SeasonPassManager.sol";
import {DeploySeasonPassManager} from "../../script/DeploySeasonPassManager.s.sol";

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

    function setUp() public {
        DeploySeasonPassManager deployer = new DeploySeasonPassManager();
        (seasonPassManager) = deployer.run();
    }

    function beforeEach() public {
        seasonPassManager = new SeasonPassManager(
            1,
            NUMBER_OF_MAX_FANS,
            MAX_SEATS,
            NUMBER_OF_ZONES,
            1 ether
        );
    }

    // Test case 1: Test startNewSeason function
    function testStartNewSeason() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.startNewSeason(200, MAX_SEATS, NUMBER_OF_ZONES);
        assertEq(
            seasonPassManager.getNumberOfMaxFans(),
            200,
            "Maximum fans should be 200"
        );
        assertEq(
            seasonPassManager.getNumberOfMaxSeats(),
            MAX_SEATS,
            "Maximum seats should be 500"
        );
        assertEq(
            seasonPassManager.getNumberOfZones(),
            NUMBER_OF_ZONES,
            "Number of zones should be 10"
        );
        assertEq(
            uint(seasonPassManager.getSeasonStages()),
            uint(SeasonPassManager.Stages.RENEWALS),
            "Season stage should be RENEWALS"
        );
    }

    // Test case 3: Test changeNumberOfSeasonIds function
    function changeNumberOfSeasonIds() public {
        vm.startPrank(seasonPassManager.owner());
        address[] memory fans = new address[](3);
        fans[0] = address(0x1);
        fans[1] = address(0x2);
        fans[2] = address(0x3);
        SeasonPassManager.Seat[] memory seatIds = new SeasonPassManager.Seat[](
            3
        );
        seatIds[0] = SeasonPassManager.Seat(address(0x1), 1, 1, 1, 1);
        seatIds[1] = SeasonPassManager.Seat(address(0x2), 2, 2, 2, 2);
        seatIds[2] = SeasonPassManager.Seat(address(0x3), 3, 3, 3, 3);
        seasonPassManager.changeNumberOfSeasonIds(fans);
        seasonPassManager.setSeatInfo(seatIds, false);
        assertEq(
            seasonPassManager.getNumberOfCurrentFans(),
            3,
            "Number of current fans should be 3"
        );
        assertEq(
            seasonPassManager.getSeasonPass(address(0x1)).idOfSeasonPass,
            1,
            "Should be 1"
        );
        assertEq(
            seasonPassManager.getSeasonPass(address(0x2)).idOfSeasonPass,
            2,
            "Should be 2"
        );
        assertEq(
            seasonPassManager.getSeasonPass(address(0x3)).idOfSeasonPass,
            3,
            "Should be 3"
        );
        assertEq(
            seasonPassManager.getSeatOfFan(address(0x1)),
            1,
            "Should be 1"
        );
        assertEq(
            seasonPassManager.getSeatOfFan(address(0x2)),
            1,
            "Should be 2"
        );
        assertEq(
            seasonPassManager.getSeatOfFan(address(0x3)),
            1,
            "Should be 3"
        );
    }

    // Test case 4: Test deleteNumberOfSeasonIds function
    function testDeleteNumberOfSeasonIds() public {
        vm.startPrank(seasonPassManager.owner());
        address[] memory fans = new address[](3);
        fans[0] = address(0x1);
        fans[1] = address(0x2);
        fans[2] = address(0x3);
        seasonPassManager.changeNumberOfSeasonIds(fans);
        seasonPassManager.deleteNumberOfSeasonIds(fans);
        assertEq(
            seasonPassManager.getNumberOfCurrentFans(),
            0,
            "Number of current fans should be 0"
        );
    }

    // Test case 2: Test advanceStage function
    function testAdvanceStage() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.advanceStage();
        assertEq(
            uint(seasonPassManager.getSeasonStages()),
            uint(SeasonPassManager.Stages.SEAT_CHANGES),
            "Season stage should be SEAT_CHANGES"
        );
    }

    // Test case 6: Test changeSeat function
    function testChangeSeat() public {
        vm.startPrank(seasonPassManager.owner());
        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        seasonPassManager.addNewFan(address(0x1), SEAT_1_ID, ZONE_1_ID);
        seasonPassManager.changeSeat(
            address(0x1),
            SEAT_1_ID,
            ZONE_1_ID,
            SEAT_2_ID,
            ZONE_1_ID
        );
        assertEq(
            seasonPassManager.getSeat(SEAT_1_ID).seatOwner,
            address(0),
            "Seat 1 should be free after changing"
        );
        assertEq(
            seasonPassManager.getSeat(SEAT_2_ID).seatOwner,
            address(0x1),
            "Seat 2 should be owned by fan 1 after changing"
        );
    }

    // Test case 7: Test addNewFan function
    function testAddNewFan() public {
        vm.startPrank(seasonPassManager.owner());
        int256[] memory maxSeatsPerZOne;
        for (uint i = 0; i < NUMBER_OF_ZONES; i++) {
            maxSeatsPerZOne[i] = 50;
        }
        seasonPassManager.modifyAvailableSeats(maxSeatsPerZOne);

        seasonPassManager.advanceStage();
        seasonPassManager.advanceStage();
        seasonPassManager.addNewFan(address(0x1), SEAT_1_ID, ZONE_1_ID);
        assertEq(
            seasonPassManager.getSeasonPass(address(0x1)).idOfSeasonPass,
            FAN_1_ID,
            "Fan 1 should have season pass ID 1"
        );
        assertEq(
            seasonPassManager.getSeasonPass(address(0x1)).seatId,
            SEAT_1_ID,
            "Fan 1 should have seat ID 1"
        );
        assertEq(
            seasonPassManager.getMaxAvailableSeats(ZONE_1_ID),
            0,
            "Maximum available seats in zone 1 should be 0"
        );
        assertEq(
            seasonPassManager.getNumberOfCurrentFans(),
            1,
            "Number of current fans should be 1"
        );
    }

    // Test case 8: Test getSeasonNumber function
    function testGetSeasonNumber() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            seasonPassManager.getSeasonNumber(),
            1,
            "Season number should be 1"
        );
    }

    // Test case 9: Test getNumberOfMaxFans function
    function testGetNumberOfMaxFans() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            seasonPassManager.getNumberOfMaxFans(),
            100,
            "Number of maximum fans should be 100"
        );
    }

    // Test case 10: Test getNumberOfCurrentFans function
    function testGetNumberOfCurrentFans() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            seasonPassManager.getNumberOfCurrentFans(),
            0,
            "Number of current fans should be 0"
        );
    }

    // Test case 11: Test getNumberOfMaxSeats function
    function testGetNumberOfMaxSeats() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            seasonPassManager.getNumberOfMaxSeats(),
            0,
            "Number of maximum seats should be 0 initially"
        );
    }

    // Test case 12: Test getNumberOfZones function
    function testGetNumberOfZones() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            seasonPassManager.getNumberOfZones(),
            0,
            "Number of zones should be 0 initially"
        );
    }

    // Test case 13: Test getSeasonStages function
    function testGetSeasonStages() public {
        vm.startPrank(seasonPassManager.owner());
        assertEq(
            uint(seasonPassManager.getSeasonStages()),
            uint(SeasonPassManager.Stages.RENEWALS),
            "Season stage should be RENEWALS initially"
        );
    }

    // Test case 14: Test getMaxAvailableSeats function
    function testGetMaxAvailableSeats() public {
        vm.startPrank(seasonPassManager.owner());
        uint256[][] memory freeSeatIds = new uint256[][](2);
        freeSeatIds[1][0] = SEAT_1_ID;
        freeSeatIds[1][1] = SEAT_2_ID;

        seasonPassManager.setSeatAvailability(freeSeatIds);
        assertEq(
            seasonPassManager.getMaxAvailableSeats(ZONE_1_ID),
            2,
            "Maximum available seats in zone 1 should be 2"
        );
    }
}
