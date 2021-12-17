// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RareBlocksInterface {
  function safeTransferFrom( address from, address to, uint256 tokenId ) external virtual;
  function ownerOf(uint256 tokenId) external view virtual returns (address owner);
  function isApprovedForAll(address sender, address cAddress) external view virtual returns (bool approval);
}

contract RentingPooled is IERC721Receiver, Ownable {
  RareBlocksInterface rareBlocks;

  uint256 deployDate; // Timestamp of deployment
  uint256 totalTimesRented; // Track total amount pass has been rented
  uint256 rentalMultiplier; // Rent multiplier to increase rent supply

  mapping(address => uint256[]) tokenOwners; // Track staked tokens
  address[] ownersAddresses; // Track owners of staked tokens

  address rareBlocksContractAddress; // Rareblocks NFT contract address
  uint256 rareBlocksCommission;
  address treasuryAddress; // Treasury

  uint256 totalOutstandingShares = 0; // Amount of outstanding shares of the treasury
  mapping(address => uint256) sharesPerWallet; // Amount of shares a wallet holds;

  uint256 _price; // Rental price
  uint256 treasury; // Accumulated treasury

  mapping(address => uint256) rentDateExpiry; // Track renter

  event Rented(address indexed _address); // Renting event
  event Staked(address indexed from, uint256 indexed tokenId, address sender); // Staking a pass
  event Unstaked(address indexed _from, uint256 indexed tokenId); // Unstaking a pass
  event Payout(uint256 indexed treasury); // Payout all stakers
  event UpdateTreasury(address indexed newAddress); // Change treasure wallet address
  event SetRareblocksContractAddress(address indexed newAddress); // When a token has added to the rent list

  constructor(uint256 price) {
    setRareblocksContractAddress(0x1bb191e56206e11b14117711C333CC18b9861262);
    treasuryAddress = 0x96E7C3bAA9c1EF234A1F85562A6C444213a02E0A;

    deployDate = block.timestamp;
    rentalMultiplier = 2;
    _price = price;
    rareBlocksCommission = 100; // Rareblocks take 10%. Uses base point, so 100 is 10%.
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

  // Rent a pass
  function rent() external payable {
    require(totalOutstandingShares > 0, "No passes have been staked");
    require(msg.value >= _price, "Not enough ether"); // Make sure the sender has enough ether to rent a pass

    /// @dev Check months since deployed. This assume 1 month is 30 days.
    uint256 monthsSinceDeploy = (block.timestamp - deployDate) /
      1000 /
      60 /
      60 /
      24 /
      30;

    /// @dev Get max rent limit per month multiplied by rental multiplier.
    /// @notice If no one rent out passes within the month, the max limit will keep on increasing.
    uint256 rentalMaxLimit = (monthsSinceDeploy * totalOutstandingShares * rentalMultiplier) + 10; // Minimum of 10
    require(rentalMaxLimit > totalTimesRented, "Maximum rental times reached");

    require( block.timestamp > rentDateExpiry[msg.sender], "You still have an active rental");

    /// @notice Record expiry date in a map. Multiply days to support multi-month rentals.    
    rentDateExpiry[msg.sender] = uint256(block.timestamp) + (30 days * (msg.value / _price));

    totalTimesRented += 1; // Increment total times rented
    treasury += msg.value; // Add fee to treasury

    emit Rented(msg.sender);
  }

  // Check if renter has active rent
  function isRentActive(address _address) external view returns (bool) {
    return block.timestamp < rentDateExpiry[_address]; // Check if current timestamp is less than expiry
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

  function stakeAndPurchaseTreasuryStock(uint256 _tokenId) public payable {
    uint256 sharePrice;
    if(treasury > 0 && totalOutstandingShares > 0){ // No divide by 0 error.
      sharePrice = treasury / totalOutstandingShares; // Amount of value in treasury per share = share price;
    }

    require(msg.value == sharePrice, "Not enough value to purchase share");
    require( rareBlocks.ownerOf(_tokenId) == msg.sender, "You do not own this token." );
    require( rareBlocks.isApprovedForAll(msg.sender, address(this)) == true, "You did not approve this contract to transfer." );

    rareBlocks.safeTransferFrom(msg.sender, address(this), _tokenId); // Transfer token to contract

    totalOutstandingShares++; // Increase outstanding shares
    sharesPerWallet[msg.sender]++; // Increase share wallet owner
    ownersAddresses.push(msg.sender); // Array of all active stakers
    tokenOwners[msg.sender].push(_tokenId); // Track tokenIds a wallet has staked
    treasury += msg.value;
  }

  // Unstake token and send back to users wallet
  function unstakeAccessPass(uint256 _tokenId) external payable {
    require(tokenOwners[msg.sender].length > 0, "You haven't staked a token.");

    bool hasTokenStaked = false;
    for (uint256 i = 0; i < tokenOwners[msg.sender].length; i++) {
      if (_tokenId == tokenOwners[msg.sender][i]) {
        hasTokenStaked = true;
      }
    }

    require(hasTokenStaked, "This tokenId has not been staked by you.");

    rareBlocks.safeTransferFrom(address(this), msg.sender, _tokenId); // Send back token to owner
    removeTokenIdFromTokenOwners(_tokenId); // Remove staked tokenId

    uint256 totalSharesOwned = sharesPerWallet[msg.sender]; // Total amount of owned shares

    if(treasury > 0){ // Only call if theres something to pay out
      uint256 valuePerShare = treasury / totalOutstandingShares; // New price per share
      uint256 totalPayoutPrice = valuePerShare * totalSharesOwned; // Price to pay for selling shares


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

      treasury -= totalPayoutPrice; // Adjust treasury
    }

    totalOutstandingShares = totalOutstandingShares - totalSharesOwned; // Reduce amount of shares outstanding

    sharesPerWallet[msg.sender] = 0; // @dev Remove shares for wallet
    emit Unstaked(msg.sender, _tokenId);
  }

  function payoutStakers() external payable {
    require(treasury > 0, "Treasury is empty");

    for (uint256 i = 0; i < ownersAddresses.length; i++) {
      uint256 shares = sharesPerWallet[ownersAddresses[i]];
      if (shares > 0) {
        uint256 valuePerShare = treasury / totalOutstandingShares; // New price per share
        uint256 totalSharesOwned = sharesPerWallet[ownersAddresses[i]]; // Total amount of owned shares
        uint256 totalPayoutPrice = valuePerShare * totalSharesOwned; // Price to pay for selling shares

        (bool success, ) = payable(ownersAddresses[i]).call{
          value: divByPercentage(totalPayoutPrice, 1000 - rareBlocksCommission)
        }(""); // Pay commission to staker
        require(success, "Failed to send Ether");
      }
    }

    (bool successRareBlocksCommission, ) = payable(treasuryAddress).call{
      value: divByPercentage(treasury, rareBlocksCommission)
    }(""); // Pay commission to staker
    require(successRareBlocksCommission, "Failed to send Ether");

    emit Payout(treasury);
    treasury = 0; // Empty treasury    
  }

  function getRentPrice() external view returns (uint256) {
    return _price;
  }

  function setRentPrice(uint256 price) public onlyOwner {
    _price = price;
  }

  // Check functions
  function getTotalOutstandingShares() external view returns (uint256) {
    return totalOutstandingShares;
  }

  function getSharesPerWallet(address owner) external view returns (uint256) {
    return sharesPerWallet[owner];
  }

  function getTotalValueInTreasury() external view returns (uint256) {
    return treasury;
  }
  
}
