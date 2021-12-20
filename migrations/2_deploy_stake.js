const Stake = artifacts.require('Stake');
 
module.exports = function(deployer) {
  // Use deployer to state migration tasks.
  deployer.deploy(Stake);
};