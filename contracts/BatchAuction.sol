// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// TODO: Test and fix Ownable import and usage
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/** 
 * @title BlindBatchAuction
 * @dev Implements sealed bid batch auction process for optimal price discovery and token allocation 
 */
contract BlindBatchAuction is ReentrancyGuard, Ownable {

    struct Bid {
        address bidder;
        uint amount; // Bid amount in Ether
        uint price;  // Maximum price the bidder is willing to pay per token
        uint priceHash; // Hashed bid price
    }

    struct Allocation {
        address bidder;
        uint allocation;  // to be claimed by user in claim function 
        uint refund;  // need not be computed in allocation/endAuction function and can be calculated during claim 
        bool claimed;
    }

    Bid[] public bids;
    uint256 public totalSupply; // Total supply of tokens to be auctioned
    uint256 public settlingPrice; // Final settling price after auction ends
    uint public auctionStartTime;
    uint public auctionEndTime;
    bool public auctionEnded;
    IERC20 public auctionedToken; // ERC-20 token being auctioned (Tokenised RWA)
    IERC20 public paymentToken; // ERC-20 token used for payment (USDT)

    mapping(address => bool) public hasClaimed; // Track if a bidder has claimed their tokens/refund

    constructor(uint _totalSupply, address _auctionedToken, address _paymentToken) {
        totalSupply = _totalSupply;
        auctionedToken = IERC20(_auctionedToken);
        paymentToken = IERC20(_paymentToken);
    }

    function configureAuction(uint _start, uint _end) external {
        require(_start < _end, "Start time must be before end time.");
        require(_end > block.timestamp, "End time must be in the future.");

        //TODO : Check bid amount and bid price are greater than minimum threshold.

        auctionStartTime = _start;
        auctionEndTime = _end;
    }


    // Make bids sealed with (bidPrice + randomised salt) => hashed and only this hashed value is passed along with bidAmount
    function placeBid(uint bidAmount, uint bidPrice) external {
        require(block.timestamp >= auctionStartTime, "Auction has not started yet.");
        require(block.timestamp <= auctionEndTime || !auctionEnded, "Auction has already ended.");
        
        // TODO: Check appropriate balance of bidAmount in paymentToken
                require( IERC20(paymentToken).balanceOf(msg.sender) >= bidAmount, " Insufficient Balance ");
        // TODO: Transfer bidAmount of paymentToken here
                IERC20(paymentToken).transfer(msg.sender,address(this),bidAmount, " Transfer failed ");

        bids.push(Bid(msg.sender, bidAmount, bidPrice, 0, 0, false));
    }

    function calculateSettlingPrice(Bid[] memory sortedBids) public {
        uint cumulativeBidAmount;
        for (uint i = 0; i < sortedBids.length; i++) {
            cumulativeBidAmount += sortedBids[i].amount;
            uint sellVolume = cumulativeBidAmount/sortedBids[i].price;
            if (sellVolume >= totalSupply) {
                settlingPrice = sortedBids[i].price;
            }
        }
    }

    function endAuction(Bid[] memory sortedBids) external onlyOwner {    
        // Decide which implementation to go ahead with 
        require(block.timestamp >= auctionStartTime, "Auction has not started yet.");
        require(!auctionEnded, "Auction has already ended.");
        auctionEnded = true;

        calculateSettlingPrice(sortedBids);
        uint256 count;
        uint i = 0;
        while (i < sortedBids.length) { 
            uint allocation = bids[i].amount / settlingPrice;  
            bids[i].allocation = allocation;
            count += bids[i].allocation;

            if(count <= totalSupply){
                bids[i].allocation = allocation;
                uint spent = bids[i].allocation * settlingPrice; 
                bids[i].refund = bids[i].amount - spent;
                i++;
            } else break;
        }
        bids[i].allocation = totalSupply - count - bids[i].allocation;
        while (i < sortedBids.length) { 
            uint spent = bids[i].allocation * settlingPrice; 
            bids[i].refund = bids[i].amount - spent;
            i++;
        }
    }

    // TODO: Finish this function 
    function claim(uint bidPrice, uint bidAmount) external {}

    // TODO: Finish this function 
    function revealIndividualBid(uint bidPrice, uint randomisedSalt) external {}

    // TODO: Finish this function 
    // function revealAllBids(uint[] bidPrice, randomisedSalt) external onlyOwner {}
}