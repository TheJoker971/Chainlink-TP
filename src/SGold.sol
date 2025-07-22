// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import { ERC20 }                 from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { AggregatorV3Interface } from "../lib/chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ILotteryGold }          from "./interfaces/ILotteryGold.sol";

/**
 * @title  SGold
 * @notice Un ERC20 “stablecoin” indexé sur le prix de l’or :
 *         • Les utilisateurs mint en déposant de l’ETH  
 *         • 20% de l’ETH va au owner, 10% à la loterie, 70% est verrouillé  
 *         • Lors du mint, on appelle participate(user) sur la loterie  
 *         • Les utilisateurs peuvent “redeem” leurs SGLD pour récupérer la part de 70% en ETH
 */
contract SGold is ERC20, Ownable {
    uint256 public immutable MAX_MINT;

    AggregatorV3Interface public constant ethUsdFeed  =
        AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
    AggregatorV3Interface public constant goldUsdFeed =
        AggregatorV3Interface(0xC5981F461d74c46eB4b0CF3f4Ec79f025573B0Ea);

    address public lotteryAddress;

    mapping(address => uint256) public reservedEther;
    mapping(address => uint256) public mintedTokens;

    event Mint   (address indexed user, uint256 ethDeposited, uint256 tokensMinted);
    event Redeem (address indexed user, uint256 tokensBurned, uint256 ethReturned);

    constructor(uint256 _MAX_MINT) ERC20("SGold", "SGLD") Ownable(msg.sender){
        MAX_MINT = _MAX_MINT;
    }

    /// @notice Définit l’adresse du contrat LotteryGold (seulement owner)
    function setLotteryAddress(address _lotteryAddress) external onlyOwner {
        lotteryAddress = _lotteryAddress;
    }

    function _getLatestPrice(AggregatorV3Interface feed) internal view returns (uint256) {
        (, int256 p, , , ) = feed.latestRoundData();
        require(p > 0, "Invalid price");
        uint8 decimals = feed.decimals();
        return uint256(p) * (10 ** (18 - decimals));
    }

    /**
     * @notice Mint de SGLD en déposant de l’ETH  
     *         20% → owner, 10% → loterie, 70% réservés  
     *         Et enregistre l’utilisateur dans la loterie
     */
    function mint() external payable {
        require(msg.value > 0, "No ETH sent");

        // répartitions
        uint256 ownerPortion   = (msg.value * 20) / 100;
        uint256 lotteryPortion = (msg.value * 10) / 100;
        uint256 reservePortion = msg.value - ownerPortion - lotteryPortion; // 70%

        // transferts
        payable(owner()).transfer(ownerPortion);
        payable(lotteryAddress).transfer(lotteryPortion);

        // enregistrement du participant
        ILotteryGold(lotteryAddress).participate(msg.sender);

        // calculs de mint
        uint256 ethUsd   = _getLatestPrice(ethUsdFeed);
        uint256 goldUsd  = _getLatestPrice(goldUsdFeed);
        uint256 reservedUsd = (reservePortion * ethUsd) / 1e18;
        uint256 tokensToMint = (reservedUsd * 1e18) / goldUsd;

        require(totalSupply() + tokensToMint <= MAX_MINT, "Exceeds max supply");

        // sauvegarde pour redemption
        reservedEther[msg.sender] += reservePortion;
        mintedTokens[msg.sender]  += tokensToMint;

        _mint(msg.sender, tokensToMint);
        emit Mint(msg.sender, msg.value, tokensToMint);
    }

    /**
     * @notice Rend des SGLD pour récupérer les ETH réservés
     */
    function redeem(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Zero tokens");
        uint256 userTokens  = mintedTokens[msg.sender];
        require(userTokens >= tokenAmount, "Too many tokens");

        uint256 userReserve = reservedEther[msg.sender];
        uint256 ethToReturn = (userReserve * tokenAmount) / userTokens;

        mintedTokens[msg.sender]  = userTokens - tokenAmount;
        reservedEther[msg.sender] = userReserve - ethToReturn;

        _burn(msg.sender, tokenAmount);
        payable(msg.sender).transfer(ethToReturn);

        emit Redeem(msg.sender, tokenAmount, ethToReturn);
    }

    receive() external payable {}
}
