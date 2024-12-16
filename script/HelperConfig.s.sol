// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import{Script,console} from "forge-std/Script.sol";
import{VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
contract HelperConfig is Script{

    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    struct NetworkConfig{
        uint64 subscriptionId;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address vrfCoordinatorV2;
        address account; //user account
    }

    NetworkConfig public localNetworkConfig;

    function getConfig() external returns(NetworkConfig memory){
        return getAnvilConfiguration();
    }

    function getAnvilConfiguration() internal returns(NetworkConfig memory){
            console.log("deploying mocks");
            
            vm.startBroadcast(vm.envUint("ANVIL_PRIVATE_KEY"));
            console.log("msg.sender",msg.sender);
            VRFCoordinatorV2Mock vrfCoordinatorV2 =
                new VRFCoordinatorV2Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK);
            
            //creating subscription
            uint64 subscriptionId = vrfCoordinatorV2.createSubscription();
            //funding the subscription
            vrfCoordinatorV2.fundSubscription(subscriptionId,20 ether);
            vm.stopBroadcast();
            localNetworkConfig=NetworkConfig({
                subscriptionId:subscriptionId,
                gasLane:0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                callbackGasLimit: 500000,
                vrfCoordinatorV2:address(vrfCoordinatorV2),
                account:FOUNDRY_DEFAULT_SENDER
            });
            return localNetworkConfig;
    }
}