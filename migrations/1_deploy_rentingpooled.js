const RentingPooled = artifacts.require('RentingPooled');
 
module.exports = function(deployer) {
  // Use deployer to state migration tasks.
  deployer.deploy(RentingPooled, BigInt(100000000000000000));
};