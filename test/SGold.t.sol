// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import { Test }     from "forge-std/Test.sol";
import { SGold }    from "../src/SGold.sol";
import { ILotteryGold } from "../src/interfaces/ILotteryGold.sol";

/// @notice Mock de la loterie pour capter les ETH envoyés
contract LotteryMock is ILotteryGold {
    uint256 public received;

    function participate(address) external override {}

    receive() external payable {
        received += msg.value;
    }

    function drawWinner() external override {}
    function indexParticipant() external view override returns (uint256) { return 0; }
    function participants(uint256) external view override returns (address) { return address(0); }
    function registry(address) external view override returns (bool)     { return false; }
}

contract SGoldTest is Test {
    SGold       token;
    LotteryMock lottery;

    /// @notice Prépare le fork et déploie
    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL"));
        lottery = new LotteryMock();
        token   = new SGold(2_000_000 ether);
        token.setLotteryAddress(address(lottery));
        vm.deal(address(this), 10 ether);
    }

    /// @notice Vérifie l’état initial
    function testInitialize() public {
        assertEq(token.MAX_MINT(),       2_000_000 ether);
        assertEq(token.name(),           "SGold");
        assertEq(token.symbol(),         "SGLD");
        assertEq(token.lotteryAddress(), address(lottery));
    }

    /// @notice Mint sans ETH doit revert
    function testMintRevertsWhenNoEth() public {
        vm.expectRevert("No ETH sent");
        token.mint();
    }

    /// @notice Mint > max supply doit revert
    function testExceedsMaxMintReverts() public {
        SGold small = new SGold(1 ether);
        small.setLotteryAddress(address(lottery));
        vm.deal(address(this), 2 ether);
        vm.expectRevert("Exceeds max supply");
        small.mint{ value: 2 ether }();
    }

    /// @notice Mint correct : vérifie l’emit, la répartition et les soldes
    function testMintEmitsAndDistributes() public {
        uint256 soldeAvant = address(this).balance;

        // on s’attend à l’event Mint avec seulement le indexed user matché
        vm.expectEmit(true, false, false, false);
        emit SGold.Mint(address(this), 0, 0);

        token.mint{ value: 1 ether }();

        // 70% doivent être réservés
        assertEq(token.reservedEther(address(this)), 0.7 ether);
        // des tokens sont bien mintés
        assertGt(token.mintedTokens(address(this)), 0);
        // le mock de loterie a reçu 10%
        assertEq(lottery.received(), 0.1 ether);
        // l'owner (ce test) a reçu 20% → coût net = 0.8 ETH
        assertEq(address(this).balance, soldeAvant - 0.8 ether);
    }

    /// @notice Redeem correct : vérifie l’emit et le remboursement partiel
    function testRedeemEmitsAndReturnsCorrectEth() public {
        // mint 1 ETH → réserve initiale
        token.mint{ value: 1 ether }();
        uint256 totalTokens      = token.mintedTokens(address(this));
        uint256 half             = totalTokens / 2;
        uint256 reservedBefore   = token.reservedEther(address(this));
        uint256 redeemed         = (reservedBefore * half) / totalTokens;
        uint256 expectedReserved = reservedBefore - redeemed;
        uint256 soldeAvant       = address(this).balance;

        // on s'attend à l’event Redeem avec la valeur calculée
        vm.expectEmit(true, false, false, true);
        emit SGold.Redeem(address(this), half, redeemed);

        token.redeem(half);

        // vérifications post-redeem
        assertEq(token.balanceOf(address(this)), totalTokens - half);
        assertEq(token.reservedEther(address(this)), expectedReserved);
        assertEq(address(this).balance, soldeAvant + redeemed);
    }

    /// @notice Permet de recevoir les ETH des transferts
    receive() external payable {}
}
