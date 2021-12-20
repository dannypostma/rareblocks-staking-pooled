// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RareBlocksInterface {
  function safeTransferFrom( address from, address to, uint256 tokenId ) external virtual;
  function ownerOf(uint256 tokenId) external view virtual returns (address owner);
  function isApprovedForAll(address sender, address cAddress) external view virtual returns (bool approval);
}

contract Stake is IERC721Receiver, Ownable {
  RareBlocksInterface rareBlocks;


  address[] ownersAddresses; // Track owners of staked tokens
  address rareBlocksContractAddress; // Rareblocks NFT contract address
  address treasuryAddress; // Treasury


    uint256 rareBlocksCommission;
    uint256 totalOutstandingShares = 0; // Amount of outstanding shares of the treasury

  mapping(address => uint256[]) tokenOwners; // Track staked tokens
  mapping(address => uint256) sharesPerWallet; // Amount of shares a wallet holds;

  event Staked(address indexed from, uint256 indexed tokenId, address sender); // Staking a pass
  event Unstaked(address indexed _from, uint256 indexed tokenId); // Unstaking a pass
  event Payout(uint256 indexed treasury); // Payout all stakers
  event UpdateTreasury(address indexed newAddress); // Change treasure wallet address
  event SetRareblocksContractAddress(address indexed newAddress); // When a token has added to the rent list
    event Received(address, uint);
    
  constructor() {
    setRareblocksContractAddress(0x1bb191e56206e11b14117711C333CC18b9861262);
    treasuryAddress = 0x96E7C3bAA9c1EF234A1F85562A6C444213a02E0A;
    rareBlocksCommission = 100; // Rareblocks take 10%. Uses base point, so 100 is 10%.
  }

  
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

  // Divide by percentage, using base point
  function divByPercentage(uint256 amount, uint256 proportion) internal pure returns (uint256){
    // @dev double check this formula, was previously wrong
    return (amount * 10000) / (10000000 / proportion);
  }

  // Set RarBlocks contract address
  function setRareblocksContractAddress(address _rbAddress) public onlyOwner {
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
  function onERC721Received( address _from, address, uint256 _tokenId, bytes calldata ) external returns (bytes4) {
    require(msg.sender == rareBlocksContractAddress, "Wrong NFT"); // Make sure only Rareblocks NFT can be staked. msg.sender is always contract address of NFT.

    tokenOwners[_from].push(_tokenId);

    emit Staked(_from, _tokenId, msg.sender);
    return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }

  // List all tokens staked by address
  function getTokensStakedByAddress(address _address) public view returns (uint256[] memory) {
    return tokenOwners[_address];
  }

  function removeTokenIdFromTokenOwners(uint256 tokenId) internal {
    for (uint256 i = 0; i < tokenOwners[msg.sender].length; i++) {
      if (tokenOwners[msg.sender][i] == tokenId) {
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

  function removeFromOwnersAddresses(address _address) internal {
    for (uint256 i = 0; i < ownersAddresses.length; i++) {
      if (ownersAddresses[i] == _address) {
        removeFromOwnersAddressesByIndex(i);
      }
    }
  }

  function removeFromOwnersAddressesByIndex(uint256 _index) internal {
    require(_index < ownersAddresses.length, "index out of bound");

    for (uint256 i = _index; i < ownersAddresses.length - 1; i++) {
      ownersAddresses[i] = ownersAddresses[i + 1];
    }
    ownersAddresses.pop();
  }

  function stakeAndPurchaseTreasuryStock(uint256 _tokenId) public payable {
    uint256 balance = address(this).balance;

    if(balance > 0 && totalOutstandingShares > 0){ // No divide by 0 error.
        /// @dev totalOutstandingShares must be added 1, because msg.value is added before body to the balance.
        uint256 sharePrice = balance / (totalOutstandingShares+1); // Amount of value in treasury per share = share price;
        require(msg.value >= sharePrice, "Not enough value to purchase share");
    }

    require(rareBlocks.ownerOf(_tokenId) == msg.sender, "You do not own this token." );
    require(rareBlocks.isApprovedForAll(msg.sender, address(this)) == true, "You did not approve this contract to transfer." );


    totalOutstandingShares++; // Increase outstanding shares
    sharesPerWallet[msg.sender]++; // Increase share wallet owner
    ownersAddresses.push(msg.sender); // Array of all active stakers
    tokenOwners[msg.sender].push(_tokenId); // Track tokenIds a wallet has staked

    rareBlocks.safeTransferFrom(msg.sender, address(this), _tokenId); // Transfer token to contract

    emit Staked(address(this), _tokenId, msg.sender);
  }

  // Unstake token and send back to users wallet
  function unstakeAccessPass(uint256 _tokenId) external payable {
    require(tokenOwners[msg.sender].length > 0, "You haven't staked a token.");
    
    uint256 treasury = address(this).balance;
    uint256 _totalOutstandingShares = totalOutstandingShares;
    
    bool hasTokenStaked = false;
    for (uint256 i = 0; i < tokenOwners[msg.sender].length; i++) {
      if (_tokenId == tokenOwners[msg.sender][i]) {
        hasTokenStaked = true;
      }
    }

    require(hasTokenStaked, "This tokenId has not been staked by you.");

    // Call variable updates before sending anything to protect from reentrancy vulnerability
    removeFromOwnersAddresses(msg.sender); // Remove staked tokenId
    totalOutstandingShares -= 1; // Reduce amount of shares outstanding
    sharesPerWallet[msg.sender] -= 1; // @dev Remove shares for wallet

    removeTokenIdFromTokenOwners(_tokenId); // Remove staked tokenId
    rareBlocks.safeTransferFrom(address(this), msg.sender, _tokenId); // Send back token to owner

    if(treasury > 0){ // Only call if theres something to pay out
      uint256 valuePerShare = treasury / _totalOutstandingShares; // New price per share
      uint256 totalPayoutPrice = valuePerShare; // Price to pay for selling shares

      uint256 stakerPayoutValue = divByPercentage(totalPayoutPrice, 1000 - rareBlocksCommission); 
      uint256 treasuryPayoutValue = divByPercentage(totalPayoutPrice, rareBlocksCommission);

      (bool successCaller, ) = payable(msg.sender).call{
        value: stakerPayoutValue
      }(""); // Pay commission to staker
      require(successCaller, "Failed to send Ether to caller");

      (bool successRareBlocksCommission, ) = payable(treasuryAddress).call{
        value: treasuryPayoutValue
      }(""); // Pay commission to staker
      
      require(successRareBlocksCommission, "Failed to send Ether to treasury");

    }
    
    emit Unstaked(msg.sender, _tokenId);
  }

  function payoutStakers() external payable {
    uint256 treasury = address(this).balance;
    require(treasury > 0, "Treasury is empty");

    uint256 treasuryValueOnPayout = treasury;

    for (uint256 i = 0; i < ownersAddresses.length; i++) {
      uint256 shares = sharesPerWallet[ownersAddresses[i]];
      if (shares > 0) {
        uint256 valuePerShare = treasuryValueOnPayout / totalOutstandingShares; // New price per share
        uint256 totalSharesOwned = sharesPerWallet[ownersAddresses[i]]; // Total amount of owned shares
        uint256 totalPayoutPrice = valuePerShare * totalSharesOwned; // Price to pay for selling shares

        (bool success, ) = payable(ownersAddresses[i]).call{
          value: divByPercentage(totalPayoutPrice, 1000 - rareBlocksCommission)
        }(""); // Pay commission to staker
        require(success, "Failed to send Ether to address");
      }
    }

    (bool successRareBlocksCommission, ) = payable(treasuryAddress).call{
      value: address(this).balance
    }(""); // Send rest of money to treasury
    require(successRareBlocksCommission, "Failed to send Ether to Treasury");

    emit Payout(treasuryValueOnPayout);
  }

  // Check functions
  function getTotalOutstandingShares() external view returns (uint256) {
    return totalOutstandingShares;
  }

  function getSharesPerWallet(address owner) external view returns (uint256) {
    return sharesPerWallet[owner];
  }

  function getAllStakerAddresses() external view returns (address[] memory) {
    return ownersAddresses;
  }

  function getSharePrice() external view returns (uint256) {
      require(totalOutstandingShares > 0, "No outstanding shares found");
        return address(this).balance / totalOutstandingShares;
  }
  
}
