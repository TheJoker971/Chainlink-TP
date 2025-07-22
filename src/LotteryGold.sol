// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import { VRFConsumerBaseV2Plus } from "../lib/chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import { VRFV2PlusClient } from "../lib/chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import { ILotteryGold } from "./interfaces/ILotteryGold.sol";

/**
 * @title LotteryGold
 * @notice Gère une loterie financée en ETH :
 *         • Le ERC20 (SGold) envoie des ETH à ce contrat, puis appelle participate(user)  
 *         • Il faut au moins 10 participants pour lancer drawWinner()  
 *         • Seul le owner peut tirer, via Chainlink VRF v2+  
 *         • Le gagnant reçoit tout le solde du contrat  
 *         • Après chaque tirage, l’état est réinitialisé pour repartir à zéro  
 */
contract LotteryGold is VRFConsumerBaseV2Plus, ILotteryGold {
    /// ─── VRF CONFIG ────────────────────────────────────────────────────────────
    uint256  private immutable s_subscriptionId;

    address private constant vrfCoordinator      = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 private constant s_keyHash           = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32  private constant callbackGasLimit    = 40000;
    uint16  private constant requestConfirmations = 3;
    uint32  private constant numWords            = 1;

    /// ─── LOTTERY STATE ─────────────────────────────────────────────────────────
    uint256 public indexParticipant;                     // compteur d’inscrits
    mapping(uint256 => address) public participants;     // index → addr
    mapping(address => bool)    public registry;         // addr → inscrit ?

    /// ─── VRF TRACKING & EVENTS ─────────────────────────────────────────────────
    uint256 private s_lastRequestId;

    /// @param subscriptionId ID de la subscription VRF v2+
    constructor(uint256 subscriptionId)
        VRFConsumerBaseV2Plus(vrfCoordinator)
    {
        s_subscriptionId = subscriptionId;
    }

    /**
     * @notice Enregistre `participant` (appelé par ERC20 après le transfert d’ETH)
     * @param participant adresse à ajouter à la loterie
     */
    function participate(address participant) external {
        require(tx.origin == owner() || msg.sender == owner(),"Not authorized");
        require(participant != address(0), "Invalid address");
        require(!registry[participant], "Already registered");

        registry[participant] = true;
        participants[indexParticipant] = participant;
        indexParticipant++;
    }

    /// @notice Lance le tirage si ≥10 participants
    function drawWinner() external onlyOwner {
        require(indexParticipant >= 10, "Need >=10 participants");

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash:              s_keyHash,
                subId:                s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit:     callbackGasLimit,
                numWords:             numWords,
                extraArgs:            VRFV2PlusClient._argsToBytes(
                                         VRFV2PlusClient.ExtraArgsV1({ nativePayment: false })
                                     )
            })
        );

        s_lastRequestId = requestId;
        emit LotteryRequested(requestId);
    }

    /// @dev Callback VRF : désigne le gagnant, lui envoie tout l’ETH, reset
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        require(requestId == s_lastRequestId, "Unknown requestId");

        uint256 idx = randomWords[0] % indexParticipant;
        address winner = participants[idx];

        uint256 prize = address(this).balance;
        (bool ok, ) = winner.call{ value: prize }("");
        require(ok, "Transfer failed");

        emit WinnerDeclared(winner, prize);

        // reset
        for (uint256 i = 0; i < indexParticipant; i++) {
            registry[participants[i]] = false;
            delete participants[i];
        }
        indexParticipant = 0;
    }

    function getLastRequestId() external view returns(uint256) {
        return s_lastRequestId;
    }

    /// @notice Pour alimenter la cagnotte depuis l’extérieur (ERC20)
    receive() external payable {}
}
