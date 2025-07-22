// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.4;

import {Script, console} from "forge-std/Script.sol";
import { IVRFSubscriptionV2Plus } from "../lib/chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";
import { SGold } from "../src/SGold.sol";
import { LotteryGold } from "../src/LotteryGold.sol";

contract ProjectScript is Script {

    IVRFSubscriptionV2Plus public vrf;
    SGold public token;
    LotteryGold public lottery;

    function setUp() public {
        vrf = IVRFSubscriptionV2Plus(0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B);
    }

    function run() public {
        vm.startBroadcast();
        uint256 uuid = 90662373945300685269312789235957117670793815766806561448085376511422831350798;
        token = new SGold(2_000_000 ether);
        lottery = new LotteryGold(uuid);
        vrf.addConsumer(uuid,address(lottery));
        token.setLotteryAddress(address(lottery));
        vm.stopBroadcast();
    }

}


