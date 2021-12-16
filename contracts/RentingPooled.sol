// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RareBlocksInterface {
    function safeTransferFrom(address from, address to, uint256 tokenId) virtual external;
}

contract RentingPooled is IERC721Receiver, Ownable{

    RareBlocksInterface rareBlocks;

    mapping(address => uint[]) tokenOwners; // Track staked tokens

    address rareBlocksContractAddress; // Rareblocks NFT contract address
    address treasuryAddress; // Treasury

    uint256 totalOutstandingShares = 0; // Amount of outstanding shares of the treasury
    mapping(address => uint256) sharesPerWallet; // Amount of shares a wallet holds;


    event Staked(address indexed from, uint256 indexed tokenId, address sender); // Staking a pass
    event Unstaked(address indexed _from, uint256 indexed tokenId); // Unstaking a pass
    event UpdateTreasury(address indexed newAddress); // Change treasure wallet address
    event SetRareblocksContractAddress(address indexed newAddress); // When a token has added to the rent list


    constructor(){
        setRareblocksContractAddress(0x1bb191e56206e11b14117711C333CC18b9861262);
        treasuryAddress = 0x96E7C3bAA9c1EF234A1F85562A6C444213a02E0A;
    }


    // Set RarBlocks contract address
    function setRareblocksContractAddress(address _rbAddress) external onlyOwner{
        rareBlocksContractAddress = _rbAddress;
        rareBlocks = RareBlocksInterface(_rbAddress);
        emit SetRareblocksContractAddress(_rbAddress);
    }

    // Change treasury address
    function updateTreasury(address _newAddress) external onlyOwner {
        treasuryAddress = _newAddress;
        emit UpdateTreasury(_newAddress);
    }

    // Function called when being transfered a ERC721 token
    // On receival add staking information to struct Stake
    function onERC721Received(address _from,  address,  uint256 _tokenId,  bytes calldata )external returns(bytes4) {
        require(msg.sender == rareBlocksContractAddress, "Wrong NFT"); // Make sure only Rareblocks NFT can be staked. msg.sender is always contract address of NFT.

        tokenOwners[_from].push(_tokenId);

        emit Staked(_from, _tokenId, msg.sender);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    // List all tokens staked by address
    function getTokensStakedByAddress(address _address) public view returns (uint[] memory) {
        return tokenOwners[_address];
    }

    
    function removeTokenIdFromTokenOwners(uint256 tokenId ) internal{
       for (uint256 i = 0; i < tokenOwners[msg.sender].length; i++){
            if(tokenOwners[msg.sender][i] == tokenId){
                removeTokenIdFromTokenOwnersByIndex(i);
            }
        }
    }

    function removeTokenIdFromTokenOwnersByIndex(uint256 _index) internal {
        require(_index < tokenOwners[msg.sender].length, "index out of bound");

        for (uint256 i = _index; i < tokenOwners[msg.sender].length - 1; i++) {
            tokenOwners[msg.sender][i] = tokenOwners[msg.sender][i + 1];
        }
        tokenOwners[msg.sender].pop();
    }


    
    

    function stakeAndPurchaseTreasuryStock(uint256 _tokenId){
        // Stock purchase formula without dilution.
        // User can stake a token, but must pay to get a share of the treasury. 
        // Staker can get his money back at any time when unstaking as the value of his stock is the same as the stoke purchase amount.

        // Example calculation (sharePrice = treasury / totalOutstandingShares)
        // Treasury: 0Eth | totalOutstandingShares: 0
        // User A stakes 2 Access Pass
        // sharePrice = 0 / 0 = 0
        // Stakes for free
        
        // Renter X rents 1 Pass for 1Eth
        // Treasury: 1Eth | totalOutstandingShares: 2 | sharePrice: 0.5Eth

        // User B Stakes 1 Access Pass
        // sharePrice = 1Eth / 2 = 0.5E
        // Stakes 1 pass + needs to pay 0.5E to buy share in treasury

        // Treasury: 1.5Eth | totalShareOutstanding: 3 | sharePrice: 0.5Eth

        // User A unstakes 2 passes
        // sharePrice = 1.5Eth / 3 = 0.5E
        // totalPayoutPrice = shares * sharePrice = 2 * 0.5 = 1Eth
        

        // Treasury: 0.5E | totalOutstandingShares: 1 | sharePrice: 0.5Eth
        
        // User B unstakes 1 pass
        // shareprice = 0.5E / 1 = 0.5E
        // totalPayoutPrice = shares * sharePrice = 1 * 0.5 = 0.5E
        // User get's back his investment of 0.5E


        uint256 sharePrice = treasury / totalOutstandingShares; // Amount of value in treasury per share = share price;

        require(msg.value == sharePrice, "Not enough value to purchase share");

        require(rareBlocks._exists(_tokenId), "This token does not exist");
        require(rareBlocks.ownerOf(_tokenId) == msg.sender, "You do not own this token.");
        require(rareBlocks.getApproved(_tokenId) == address(this), "You did not approve this contract to transfer.");

        rareBlocks.safeTransferFrom(msg.sender, address(this), _tokenId); // Transfer token to contract

        totalOutstandingShares++;
        sharesPerWallet[msg.sender]++;
    }

    // Unstake token and send back to users wallet
    function unstakeAccessPass(uint256 _tokenId) external {
        require(tokenOwners[msg.sender].length > 0, "You haven't staked a token.");

        bool hasTokenStaked = false;
        for (uint i=0; i < tokenOwners[msg.sender].length; i++) {
            if (_tokenId == tokenOwners[msg.sender][i]) {
                hasTokenStaked = true;
            }
        }

        require(hasTokenStaked, "This tokenId has not been staked by you.");

        rareBlocks.safeTransferFrom(address(this), msg.sender, _tokenId); // Send back token to owner
        removeTokenIdFromTokenOwners(_tokenId); // Remove staked tokenId

        
        uint256 valuePerShare = treasury / totalOutstandingShares; // New price per share
        uint256 totalSharesOwned = sharesPerWallet[msg.sender]; // Total amount of owned shares
        uint256 totalPayoutPrice = valuePerShare * totalSharesOwned; // Price to pay for selling shares

        totalOutstandingShares = totalOutstandingShares - sharesPerWallet[msg.sender]; // Reduce amount of shares outstanding
        sharesPerWallet[msg.sender] = 0; // Remove shares for wallet

        (bool success, ) = payable(msg.sender).call{value: totalPayoutPrice}(""); // Pay commission to staker
        emit Unstaked(msg.sender, _tokenId);
        require(success, "Failed to send Ether");
    }

}


// @TODO How to pool stake?

/* 

When staking token:
+ Get future profits from day of staking
- Don't get past profits before day of staking

? Count days in pool?
? Count amount of passes in pool?

User A stakes pass on day 1
User B stakes pass on day 15

Customer A rents on day 1 for 1Eth
Customer B rents on day 15 for 1Eth

User B claims on day 30
- Days in pool: 15
- Total days in pool: 30
- Total stakers: 2
- Total treasury = 2
-> Cut = stakedDays / totalPoolDays / totalStakers = 15 / 30 / 2 = 0.5Eth

User A claims on day 30
- Days in pool: 30
- Total Days in pool: 30
- Total stakers: 1
- Total treasury: 1.5
-> Cut = stakedDays / totalPoolDays / totalStakers = 30 / 30 / 1  = 1.5


-------

User A stakes pass on day 1
User B stakes pass on day 15
User C stakes pass on day 28

Customer A rents on day 1 for 1Eth
Customer B rents on day 15 for 1Eth

User B claims on day 30
- Days in pool: 15
- Total days in pool: 30
- Total stakers: 3
- Total treasury = 2
-> Cut = stakedDays / totalPoolDays / totalStakers = 15 / 30 / 3 = 0.16667Eth

User A claims on day 30
- Days in pool: 30
- Total Days in pool: 30
- Total stakers: 2
- Total treasury: 1.83333
-> Cut = stakedDays / totalPoolDays / totalStakers = 30 / 30 / 2  = 0.5


DOES NOT WORK 

-------


Rent shares: 0
Rent treasury: 0 Eth

User A stakes 2 passes:
- User A shares: 2
- Total Rent shares: 2

User B stakes 1 pass:
- User B shares: 1
- Total rent shares: 3
- 1 share value: 0E

Renter X rents 1 pass for 1 Eth:
- Rent treasury: +1

User A share value: 1(value) / 3 (totalShares) = 0.33 * shares  0.66
User B shares value: 0.33

User C stakes 1 pass:
- User C shares: 1
- Total rent shares: 4
- Payment to purchase share: totalTreasury / totalShare = 0.33
- New treasury: 1.33E
1 share value: 0.33Eth -> Treasury / Total shares

User C unstakes 1 pass:
- 0.33E profit (treasury / total Shares * owned shares) -> 1.33 / 4 * 1 = .33
- Owes the treasury 0.33, so profit = 0.33 - 0.33 = 0
- User C shares: 0
- Total rent shares: 3

Treasury: 0.75

User A unstakes 2 passes:
- 0.5E profit
- User A shares: 0
- Total rent shares: 1

*/

/*
1. Set approval for transfering ERC721
2. Send stock purchase amount to contract
3. Staked




*/