// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract StakeInterface {
  function getTotalOutstandingShares() external view virtual returns (uint256 totalOutstandingShares); // Count amount of staked access passes
}

contract Rent is Ownable {
  StakeInterface stake;

  uint256 deployDate; // Timestamp of deployment
  uint256 totalTimesRented; // Track total amount pass has been rented
  uint256 rentalMultiplier; // Rent multiplier to increase rent supply
  uint256 _price; // Rental price
  bool isRentable; // Contract open for renting

  address stakeContractAddress;

  mapping(address => uint256) rentDateExpiry; // Track renter

  event Rented(address indexed _address); // Renting event
  event UpdateStakeContractAddress(address indexed newAddress); // When a token has added to the rent list
  event Payout(uint256 indexed _amount); // Payout all stakers

  constructor(uint256 price) {
    setStakeContractAddress(0x1bb191e56206e11b14117711C333CC18b9861262); // Staking Contract Address

    deployDate = block.timestamp;
    rentalMultiplier = 2;
    _price = price;
    isRentable = false;
  }

  function setStakeContractAddress(address _address) public onlyOwner {
    stakeContractAddress = _address;
    stake = StakeInterface(_address);
    emit UpdateStakeContractAddress(_address);
  }

  // Change if customers can rent or not
  function setIsRentable(bool status) public onlyOwner {
    isRentable = status;
  }

  // Rent a pass
  function rent() external payable {
    require(isRentable, "Renting is currently offline");
    
    /// @dev Get total amount of staked NFTs in Stake contract
    uint256 totalOutstandingShares = stake.getTotalOutstandingShares();
    require(totalOutstandingShares > 0, "No passes have been staked");

    require(msg.value >= _price, "Not enough ether"); // Make sure the sender has enough ether to rent a pass

    /// @dev Check months since deployed. This assume 1 month is 30 days.
    uint256 monthsSinceDeploy = (block.timestamp - deployDate) / 1000 / 60 / 60 / 24 / 30;

    /// @dev Get max rent limit per month multiplied by rental multiplier.
    /// @notice If no one rent out passes within the month, the max limit will keep on increasing.
    uint256 rentalMaxLimit = (monthsSinceDeploy * totalOutstandingShares * rentalMultiplier) + 10; // Minimum of 10
    require(rentalMaxLimit > totalTimesRented, "Maximum rental times reached");

    require( block.timestamp > rentDateExpiry[msg.sender], "You still have an active rental");

    /// @notice Record expiry date in a map. Multiply days to support multi-month rentals.    
    rentDateExpiry[msg.sender] = uint256(block.timestamp) + (30 days * (msg.value / _price));
    totalTimesRented += 1; // Increment total times rented

    (bool success, ) = payable(stakeContractAddress).call{ // Direct payment to Stake contract
      value: address(this).balance
    }("");

    emit Rented(msg.sender);
  }

  // Check if renter has active rent
  function isRentActive(address _address) external view returns (bool) {
    return block.timestamp < rentDateExpiry[_address]; // Check if current timestamp is less than expiry
  }

  function getRentPrice() external view returns (uint256) {
    return _price;
  }

  function setRentPrice(uint256 price) public onlyOwner {
    _price = price;
  }

  /// @dev Send full balance to staking contract
  function transferFundsToStakerContract() external payable{
    uint256 contractBalance = address(this).balance;
    require(contractBalance > 0, "Contract balance is empty");
    
    (bool success, ) = payable(stakeContractAddress).call{
      value: contractBalance
    }("");
    require(success, "Failed to send Ether to Stake contract");
    emit Payout(contractBalance);
  }
  
}
