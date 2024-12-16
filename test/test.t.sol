// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.20;

import{Test,console} from "forge-std/Test.sol";
import{DeployTwentyOne} from "../script/DeployTwentyOne.s.sol";
import{TwentyOne} from "../src/TwentyOne.sol";
contract Sample is Test{
    DeployTwentyOne deployer;
    TwentyOne twenyOne;
    function setUp() public{
        deployer=new DeployTwentyOne();
        twenyOne=deployer.run();
    }

    function testRandomNumberIsCorrect() public{
        console.log("owner",twenyOne.s_owner());
        uint256 expected=twenyOne.getCardDrawn();
        twenyOne.startGame{value:1 ether}();
        uint256 actual=twenyOne.drawCard(address(this));
        assert(expected==actual);
    }    
}