// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

interface ILotteryGold {
    /// @notice Enregistre un participant (appelé par le ERC20 après transfert d’ETH)
    /// @param participant adresse à ajouter à la loterie
    function participate(address participant) external;

    /// @notice Lance le tirage si au moins 10 participants sont enregistrés
    function drawWinner() external;

    /// @notice Retourne le nombre total de participants inscrits
    function indexParticipant() external view returns (uint256);

    /// @notice Retourne l’adresse du participant à un index donné
    /// @param idx index du participant (0-based)
    function participants(uint256 idx) external view returns (address);

    /// @notice Informe si une adresse est déjà inscrite
    /// @param user adresse à vérifier
    function registry(address user) external view returns (bool);

    /// @notice Event émis lors de la requête VRF
    /// @param requestId identifiant de la requête aléatoire
    event LotteryRequested(uint256 indexed requestId);

    /// @notice Event émis lorsque le gagnant est désigné et payé
    /// @param winner adresse du gagnant
    /// @param prize montant en wei envoyé
    event WinnerDeclared(address indexed winner, uint256 prize);
}
