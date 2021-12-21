const Rent = artifacts.require('Rent');
 
module.exports = function(deployer) {
  // Use deployer to state migration tasks.
  const stakeAddress = 0x1bb191e56206e11b14117711C333CC18b9861262;
  const treasuryAddress = 0x96E7C3bAA9c1EF234A1F85562A6C444213a02E0A;
  deployer.deploy(Rent, BigInt(10000000000000000, stakeAddress, treasuryAddress));
};