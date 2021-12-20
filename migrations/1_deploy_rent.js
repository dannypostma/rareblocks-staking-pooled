const Rent = artifacts.require('Rent');
 
module.exports = function(deployer) {
  // Use deployer to state migration tasks.
  deployer.deploy(Rent, BigInt(100000000000000000));
};