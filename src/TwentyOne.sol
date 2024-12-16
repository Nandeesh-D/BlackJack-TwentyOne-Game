

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import{console} from "forge-std/console.sol";
contract TwentyOne is VRFConsumerBaseV2Plus{

    // owner of the protocol
    address public s_owner;

    uint256 public activePlayers;
    uint256 private cardDrawn; 
    struct PlayersCards {
        uint256[] playersCards;
    }

    struct DealersCards {
        uint256[] dealersCards;
    }

    mapping(address => PlayersCards) playersDeck;
    mapping(address => DealersCards) dealersDeck;
    mapping(address => uint256[]) private availableCards;
    mapping(uint256 => address) private vrfRequestToPlayer;  // to track the player based on requestId in fullfillRandomwords

    event PlayerLostTheGame(string message, uint256 cardsTotal);
    event PlayerWonTheGame(string message, uint256 cardsTotal);
    event PlayerRewarded(address player, uint256 amount);
    event DealerUpCard(uint256 card);  // to show the face up card of the dealer
    event NaturalBlackjack(address player);
    event GamePush(string message, uint256 handValue);
    event BetReturned(address player, uint256 amount);
    event EtherDeposited(address,uint256);
    event RandomNumberGenerated(string);
    

    // Chainlink VRF Variables
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    
    constructor(
        uint256 subscriptionId,
        bytes32 gasLane, // keyHash
        uint32 callbackGasLimit,
        address vrfCoordinatorV2
    ) VRFConsumerBaseV2Plus(vrfCoordinatorV2) payable{
        //set the owner
        s_owner=msg.sender;
        i_subscriptionId = subscriptionId;
        i_gasLane = gasLane;
        i_callbackGasLimit = callbackGasLimit;
    }

    modifier _onlyOwner() {
        require(msg.sender == s_owner, "not the contract's owner");
        _;
    }

    receive() external payable{
        emit EtherDeposited(msg.sender,msg.value);
    }
    function addCardForPlayer(address player, uint256 card) internal {
        playersDeck[player].playersCards.push(card);
    }

    function addCardForDealer(address player, uint256 card) internal {
        dealersDeck[player].dealersCards.push(card);
    }

    function playersHand(address player) public view returns(uint256){
            uint256 playerTotal = 0;
            uint256 aceCount = 0; // track the number of Aces
            
            for (uint256 i = 0; i < playersDeck[player].playersCards.length; i++) {  
                uint256 cardValue = playersDeck[player].playersCards[i] % 13;  

                if (cardValue == 0 || cardValue >= 10) {  
                    playerTotal += 10; // face cards are worth 10  
                } else if (cardValue == 1) {  
                    aceCount++;  
                    playerTotal += 11; // by default treat Ace as 11  
                } else {  
                    playerTotal += cardValue; // numeric cards retain their value  
                }  
            }  

            // adjust Aces if total exceeds 21  
            while (playerTotal > 21 && aceCount > 0) {  
                playerTotal -= 10; // convert one Ace from 11 to 1  
                aceCount--;  
            }  

            return playerTotal;  
    }


    function dealersHand(address player) public view returns (uint256) {
        uint256 dealerTotal = 0;
        uint256 aceCount = 0; // track the number of Aces
        for (uint256 i = 0; i < dealersDeck[player].dealersCards.length; i++) {
            uint256 cardValue = dealersDeck[player].dealersCards[i] % 13;
            
             if (cardValue == 0 || cardValue >= 10) {  
                dealerTotal += 10; // face cards are worth 10  
                } else if (cardValue == 1) {  
                    aceCount++;  
                    dealerTotal += 11; // by default treat Ace as 11  
                } else {  
                    dealerTotal += cardValue; // numeric cards retain their value  
                }  
        }
        return dealerTotal;
    }


    // Initialize the player's card pool when a new game starts
    function initializeDeck(address player) internal {
        require(
            availableCards[player].length == 0,
            "Player's deck is already initialized"
        );
        for (uint256 i = 1; i <= 52; i++) {
            availableCards[player].push(i);   
        }
    }


    // Draw a random card for a specific player
    function drawCard(address player) public returns (uint256) {
        require(
            availableCards[player].length > 0,
            "No cards left to draw for this player"
        );
        console.log("entered");
        // Generate a random index
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );
        console.log("exited");
        emit RandomNumberGenerated("random number generated");

        return cardDrawn;
    }


    function startGame() public payable {
        require(_canPayout(),"Could not be payout");
        address player = msg.sender;
        
        require(msg.value == 1 ether, "not enough ether sent");
        initializeDeck(player);
        console.log("working");
        //deal with player cards
        uint256 playerCard1 = drawCard(player);
        console.log("working");
        uint256 playerCard2 = drawCard(player);
        addCardForPlayer(player, playerCard1);
        addCardForPlayer(player, playerCard2);

        //deal with dealer cards
        uint256 dealerCard1=drawCard(player);
        uint256 dealerCard2=drawCard(player);
        addCardForDealer(player, dealerCard1);
        addCardForDealer(player, dealerCard2);
        //one of the dealers card must be face up
        emit DealerUpCard(dealerCard1);
        
        ++activePlayers;  //if game is started successfully then increase the activeplayers count by 1
    }


    //@notice returns the dealer face up card
    function getDealerUpCard(address player) public view returns (uint256) {
        require(dealersDeck[player].dealersCards.length > 0, "No dealer cards");
        return dealersDeck[player].dealersCards[0];
    }

    function hit() public {
        require(
            playersDeck[msg.sender].playersCards.length > 0,
            "Game not started"
        );
        uint256 handBefore = playersHand(msg.sender);
       
        require(handBefore <= 21, "User is bust"); 
        // draw new card 
        uint256 newCard = drawCard(msg.sender);

        addCardForPlayer(msg.sender, newCard);
        uint256 handAfter = playersHand(msg.sender);
        if (handAfter > 21) {
            emit PlayerLostTheGame("Player is bust", handAfter);
            endGame(msg.sender, false,false);
        }
    }

    function call() public {
        require(
            playersDeck[msg.sender].playersCards.length > 0,
            "Game not started"
        );
        uint256 playerHand = playersHand(msg.sender);

        // dealer's threshold i.e 17 
        uint256 standThreshold = 17;

        // dealer draws cards until their hand reaches or exceeds the threshold
        while (dealersHand(msg.sender) < standThreshold) {
            uint256 newCard = drawCard(msg.sender);  
            addCardForDealer(msg.sender, newCard);
        }   

        uint256 dealerHand = dealersHand(msg.sender);
        
        //check for natural blackjack for palyer
        if (hasNaturalBlackjackForPlayer(msg.sender)) {
            if(!hasNaturalBlackjackForDealer(msg.sender)) {
                // Player Blackjack beats any non-Blackjack dealer hand
                endGame(msg.sender, true,false);
            } else {
                // Push if both have Blackjack
                endGame(msg.sender, false,true);
            }
        }else if(hasNaturalBlackjackForDealer(msg.sender)) {
            if(!hasNaturalBlackjackForPlayer(msg.sender)){
                //dealers natural blackjack
                endGame(msg.sender,false,false);
            }else {
                // Push if both have Blackjack
                endGame(msg.sender, false,true);
            }
        }//check for winer
        else if (dealerHand > 21) {   
            emit PlayerWonTheGame("Dealer went bust, players winning hand: ", playerHand);
            endGame(msg.sender, true,false);
        }else if (playerHand > dealerHand) {
            emit PlayerWonTheGame("Dealer's hand is lower, players winning hand: ", playerHand);
            endGame(msg.sender, true,false);
        } else if (playerHand == dealerHand) {
            emit GamePush("Push - equal hands", playerHand);
            endGame(msg.sender, false, true);
        } else {
            emit PlayerLostTheGame("Dealer's hand is higher, dealers winning hand: ", dealerHand);
            endGame(msg.sender, false,false);
        }
    }


    function endGame(address player, bool playerWon, bool isPush) internal {
            delete playersDeck[player].playersCards;
            delete dealersDeck[player].dealersCards;
            delete availableCards[player];
            if (playerWon) {
                payable(player).transfer(2 ether);
                emit PlayerRewarded(player, 2 ether);
            } else if (isPush) {   // if tie happened
                payable(player).transfer(1 ether); // return original bet
                emit BetReturned(player, 1 ether);
            }

            //endgame means one player had finished their game then decrement activePlayers by 1
            --activePlayers;  
    }

    function _canPayout() public view returns (bool) {
       return address(this).balance >= (activePlayers + 1) * 2;
   }


    //to withdraw the remaining ether in the contract
    function withdrawRemainingEther(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient contract balance");
        (bool success, ) = s_owner.call{value: amount}("");
        require(success, "Withdrawal failed");
    }

    //to track the occurence of natural blackjack
    function hasNaturalBlackjackForPlayer(address player) internal view returns (bool) {
        return playersDeck[player].playersCards.length == 2 && 
            playersHand(player) == 21;
    }

    function hasNaturalBlackjackForDealer(address player) internal view returns(bool){
        return dealersDeck[player].dealersCards.length == 2 && 
            dealersHand(player) == 21;
    }

   
    /**
     * @dev This is the function that Chainlink VRF node
     * calls to send the money to the random winner.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address player = vrfRequestToPlayer[requestId];
        require(player != address(0), "Invalid request ID");

        uint256 randomIndex = randomWords[0] % availableCards[player].length;

        cardDrawn = availableCards[player][randomIndex];
        availableCards[player][randomIndex] = availableCards[player][
            availableCards[player].length - 1
        ];
        availableCards[player].pop();
        addCardForPlayer(player, cardDrawn);
      
        delete vrfRequestToPlayer[requestId];
    }


    function getCardDrawn() public view returns(uint256){
        return cardDrawn;
    }


    function getPlayerCards(
        address player
    ) public view returns (uint256[] memory) {
        return playersDeck[player].playersCards;
    }

    function getDealerCards(
        address player
    ) public view returns (uint256[] memory) {
        return dealersDeck[player].dealersCards;
    }
}




