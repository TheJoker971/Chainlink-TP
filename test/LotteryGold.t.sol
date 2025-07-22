// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LotteryGold}      from "../src/LotteryGold.sol";
import {SGold}            from "../src/SGold.sol";

contract LotteryGoldTest is Test {
    VRFCoordinatorV2Mock public vrfMock;
    LotteryGold          public lottery;
    SGold                public token;
    uint64               public subId;

    /// @notice Permet à ce test de recevoir l'ETH renvoyé par fulfillRandomWords
    receive() external payable {}

    function setUp() public {
        // 1) on crédite l’adresse du test
        vm.deal(address(this), 100 ether);

        // 2) deploy du mock VRFCoordinator
        vrfMock = new VRFCoordinatorV2Mock(0.1 ether,
            1e9
        );

        // 3) création + financement de la subscription
        subId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subId, 10 ether);

        // 4) deploy de LotteryGold + enregistrement du consumer
        lottery = new LotteryGold(subId);
        vrfMock.addConsumer(subId, address(lottery));

        // 5) deploy du token et linkage à la loterie
        token = new SGold(2_000_000 ether);
        token.setLotteryAddress(address(lottery));
    }

    /// @notice Cannot draw if < 10 participants
    function testCannotDrawBefore10() public {
        vm.expectRevert("Need >=10 participants");
        lottery.drawWinner();
    }

    /// @notice participate with zero address reverts
    function testParticipateRevertsOnBadAddress() public {
        vm.expectRevert("Invalid address");
        lottery.participate(address(0));
    }

    /// @notice duplicate participate reverts
    function testParticipateRevertsOnDuplicate() public {
        // première inscription OK
        lottery.participate(address(1));
        // seconde pour la même adresse
        vm.expectRevert("Already registered");
        lottery.participate(address(1));
    }

    /// @notice only owner (this) peut inscrire
    function testNonOwnerCannotParticipate() public {
        vm.prank(address(2));
        vm.expectRevert("Not authorized");
        lottery.participate(address(2));
    }

    
}
