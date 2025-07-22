// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {SGold} from "../src/SGold.sol";
import {LotteryGold} from "../src/LotteryGold.sol";

contract ProjectAutonomeMockScript is Script {
    /// @notice Mock VRF coordinator
    VRFCoordinatorV2Mock public vrfMock;
    /// @notice Token et lottery à déployer
    SGold public token;
    LotteryGold public lottery;
    /// @dev Paramètres du mock (base fee et gas price link)
    uint96 constant BASE_FEE       = 0.1 ether;
    uint96 constant GAS_PRICE_LINK = 1e9;
    /// @notice ID de subscription VRF
    uint64 public subscriptionId;

    function run() external {
        vm.startBroadcast();

        // 1) Déploiement du mock VRFCoordinator
        vrfMock = new VRFCoordinatorV2Mock(
            BASE_FEE,
            GAS_PRICE_LINK
        );

        // 2) Création et financement de la subscription
        subscriptionId = vrfMock.createSubscription();
        // Ici on simule le funding avec "LINK" (10 LINK équivalent)
        vrfMock.fundSubscription(subscriptionId, 10 ether);

        // 3) Déploiement des contrats SGold & LotteryGold
        token   = new SGold(2_000_000 ether);
        lottery = new LotteryGold(subscriptionId);

        // 4) Enregistrement du consumer dans le mock
        vrfMock.addConsumer(subscriptionId, address(lottery));

        // 5) Liaison token ↔ lottery
        token.setLotteryAddress(address(lottery));

        vm.stopBroadcast();
    }
}
