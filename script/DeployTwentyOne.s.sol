// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;


import{Script,console} from "forge-std/Script.sol";
import{TwentyOne} from "../src/TwentyOne.sol";
import{HelperConfig} from "../script/HelperConfig.s.sol";
import{VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
contract DeployTwentyOne is Script{

    HelperConfig helperConfig;
    function run() external returns(TwentyOne){
        helperConfig=new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast(vm.envUint("ANVIL_PRIVATE_KEY"));
        TwentyOne twentyOne=new TwentyOne(config.subscriptionId,config.gasLane,config.callbackGasLimit,config.vrfCoordinatorV2);
        
        //added consumer contract
        VRFCoordinatorV2Mock(config.vrfCoordinatorV2).addConsumer(config.subscriptionId, address(twentyOne));
        console.log("added consumer");
        vm.stopBroadcast();
        return twentyOne;
    }
}