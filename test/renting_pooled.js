const Rent = artifacts.require("Rent");
const Stake = artifacts.require("Stake");
const RareBlocks = artifacts.require("RareBlocks");
const utils = require("./helpers/utils");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */

contract("RareBlocks", function (accounts) {
  let [alice, bob, charlie, treasury, renter] = accounts;
  const divider = 1000000000000000000;
  const gasPriceInGwei = 20;
  function gasToEther(value){
    return value * 20 * 0.000000001
  }
  BigInt.prototype.toJSON = function() {       
    return this.toString()
  }

  let instance;
  beforeEach('should setup the contract instance', async () => {
    instance = await RareBlocks.deployed();
    rentInstance = await Rent.deployed();
    stakeInstance = await Stake.deployed();
  });
  describe('When deploying the contract, it', () => {

    it("should have an access pass supply of 500", async function () {
      const result = await instance.getAccessPassSupply();
      const supply = result.words[0];
      assert.equal(supply, 500);
    });

    it("should have a price of 0.08 eth", async function () {
      const result = await instance.getPrice();
      const price = result.words[0];
      assert.equal(price, 34078720); // In Ether
    });

    it("should have minted 15 tokens on deploy", async function () {
      const result = await instance.getTokenCount();
      const tokens = result.words[0];
      assert.equal(tokens, 15);
    });

    it("should allow the owner to open the regular mint", async () => {
      await instance.setOpenMintActive(true);
    });

    it("should be able to mint for 0.08Eth", async function () {
      const from = alice;
      const value = 80000000000000000;
      const result = await instance.mint(alice, 1, {from, value});
      assert.equal(result.receipt.status, true)
    });

    it("should show that Alice owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, alice);
    });

    it("should mint a token for Bob", async function () {
      const from = bob;
      const value = 80000000000000000;
      const result = await instance.mint(bob, 1, {from, value});
      assert.equal(result.receipt.status, true)
    });

    it("should show that Bob owns tokenId 17", async function(){
      const result = await instance.ownerOf(17);
      assert.equal(result, bob);
    });
    

    it("should set Rareblocks contract address", async function(){
      await stakeInstance.setRareblocksContractAddress(instance.address);
    });

    it("should set Stake contract address", async function(){
      await rentInstance.setStakeContractAddress(stakeInstance.address);
    });
  });


  describe('Before staking, it', () => {
    it("cannot call stakeAndPurchaseTreasuryStock, because token is not approved", async function () {
      await utils.shouldThrow(stakeInstance.stakeAndPurchaseTreasuryStock(1, {from: alice, value: 0}));
    });

    it("should show contract is NOT approved by Alice", async function () {
      const result = await instance.isApprovedForAll(alice, stakeInstance.address);
      assert.equal(result, false);
    });

    it("should send let Alice call setApprovalForAll", async function () {
      await instance.setApprovalForAll(stakeInstance.address, true)
    });

    it("should show contract is approved by Alice", async function () {
      const result = await instance.isApprovedForAll(alice, stakeInstance.address);
      assert.equal(result, true);
    });

    it("should show contract is NOT approved by Bob", async function () {
      const result = await instance.isApprovedForAll(bob, stakeInstance.address);
      assert.equal(result, false);
    });

    it("should send let Bob call setApprovalForAll", async function () {
      await instance.setApprovalForAll(stakeInstance.address, true, {from: bob})
    });

    it("should show contract is approved by Bob", async function () {
      const result = await instance.isApprovedForAll(bob, stakeInstance.address);
      assert.equal(result, true);
    });
    


    it("cannot call stakeAndPurchaseTreasuryStock, does not own tokenId 17", async function () {
      await utils.shouldThrow(stakeInstance.stakeAndPurchaseTreasuryStock(17, {from: alice, value: 0}));
    });
  });

  describe('When renting before any passes are staked, it', () => {
    it("should not be able to rent for free", async function () {
      await utils.shouldThrow(rentInstance.rent());
    });

    it("should not be able to rent by paying", async function () {
      await utils.shouldThrow(rentInstance.rent({from: renter, value: 100000000000000000}));
    });
  });

  describe('When staking, it', () => {

    it("can stake tokenId 16 for free, because shares are worth 0", async function () {
      await stakeInstance.stakeAndPurchaseTreasuryStock(16, {from: alice, value: 0});
    });

    it("should show that Renting Contract owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, stakeInstance.address);
    });

    it("should count 1 outstanding share", async function () {
      const result = await stakeInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 1)
    });

    it("should count 1 share for Alice", async function () {
      const result = await stakeInstance.getSharesPerWallet(alice);
      assert.equal(BigInt(result), 1)
    });

    it("should show an empty treasury value", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result, 0)
    });

    it("can stake tokenId 17 by Bob for free, because shares are worth 0", async function () {
      await stakeInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 0});
    });

    it("should show that Renting Contract owns tokenId 17", async function(){
      const result = await instance.ownerOf(17);
      assert.equal(result, stakeInstance.address);
    });

    it("should count 2 outstanding share", async function () {
      const result = await stakeInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 2)
    });

    it("should count 1 share for Bob", async function () {
      const result = await stakeInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 1)
    });
    it("should count 1 share for Alice", async function () {
      const result = await stakeInstance.getSharesPerWallet(alice);
      assert.equal(BigInt(result), 1)
    });

    it("should show an empty treasury value", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(BigInt(result), 0)
    });

    
    
  });
  

  describe('When unstaking with an empty treasury, it', () => {
    it("should NOT let Bob unstake Alice her pass", async function () {
      await utils.shouldThrow(stakeInstance.unstakeAccessPass(16, {from: bob}));
    });

    it("should return an array length of 1, with tokenId 17 on index 0 for Bob", async function () {
      const result = await stakeInstance.getTokensStakedByAddress(bob);
      assert.equal(result.length, 1)
      assert.equal(BigInt(result[0]), 17)
    });

    it("should let Bob unstake tokenId 17", async function () {
      await stakeInstance.unstakeAccessPass(17, {from: bob});
    });

    it("should return an array length of 0 for Bob", async function () {
      const result = await stakeInstance.getTokensStakedByAddress(bob);
      assert.equal(result.length, 0)
    });

    it("should show that Bob owns tokenId 17", async function(){
      const result = await instance.ownerOf(17);
      assert.equal(result, bob);
    });

    it("should count 1 outstanding share", async function () {
      const result = await stakeInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 1)
    });

    it("should count 0 share for Bob", async function () {
      const result = await stakeInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 0)
    });

    it("should show an empty treasury value", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(BigInt(result), 0)
    });

    it("should let Bob restake for free", async function () {
      await stakeInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 0});
    });
  });


  describe('When renting, after passes have been staked, it', () => {

    it("should show unactive rental for this wallet", async function () {
      const result = await rentInstance.isRentActive(renter);
      assert.equal(result, false)
    });

    it("should NOT be able to rent for free", async function () {
      await utils.shouldThrow(rentInstance.rent({from: renter, value: 0}));
    });

    it("should NOT be able to rent when renting is closed", async function () {
      const value = 100000000000000000;
      const from = renter;
      await utils.shouldThrow(rentInstance.rent({from, value}));
    });

    it("should open the rent", async function () {
      await rentInstance.setIsRentable(true);
    });

    it("should be able to rent for 1E", async function () {
      const value = 100000000000000000;
      const from = renter;
      await rentInstance.rent({from, value});
    });

    it("should show a Rent Contract balance of 0.1E", async function () {
      const result = await web3.eth.getBalance(rentInstance.address);
      assert.equal(BigInt(result), 100000000000000000)
    });

    it("should be NOT able to rent another pass for 1E", async function () {
      const value = 100000000000000000;
      const from = renter;
      await utils.shouldThrow(rentInstance.rent({from, value}));
    });

    it("should show a Rent Contract balance of 0.1E", async function () {
      const result = await web3.eth.getBalance(rentInstance.address);
      assert.equal(result, 100000000000000000)
    });

    it("should show ACTIVE rental for this wallet", async function () {
      const result = await rentInstance.isRentActive(renter);
      assert.equal(result, true)
    });
  });

  describe('Before unstaking, with full Rent balance and empty Treasury balance, it', () => {
    it("should have 1Eth in Rent contract wallet", async function () {
      const result = await web3.eth.getBalance(rentInstance.address);
      assert.equal(result, 100000000000000000)
    });

    it("should have 0Eth in Stake contract wallet", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result, 0)
    });

    it("should send all off Rent balance to Stake contract balance", async function () {
      await rentInstance.transferFundsToStakerContract();
    });

    it("should have 0Eth in Rent contract wallet", async function () {
      const result = await web3.eth.getBalance(rentInstance.address);
      assert.equal(result, 0)
    });

    it("should have 1Eth in Stake contract wallet", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result, 100000000000000000)
    });
  });

  describe('When unstaking, with a full treasury, it', () => {
    it("should have 1Eth in contract wallet", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result, 100000000000000000)
    });

    it("should let Bob unstake tokenId 17 and earn his interest", async function () {
      const preValue = await web3.eth.getBalance(bob);
      await stakeInstance.unstakeAccessPass(17, {from: bob});
      const postValue = await web3.eth.getBalance(bob);
      const walletIncreaseForBob = postValue - preValue;
      assert.equal(walletIncreaseForBob/divider > 0.04, true);
    });

    it("should show an treasury value of 0.05", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result > 49000000000000000, true)
    });

    it("should count 1 outstanding share", async function () {
      const result = await stakeInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 1)
    });

    it("should count 0 share for Bob", async function () {
      const result = await stakeInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 0)
    });
  });

  describe('When staking, with a full treasury, it', () => {
    it("can NOT stake tokenId 17 for free, because treasury is not empty", async function () {
      await utils.shouldThrow(stakeInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 0}));
    });

    it("can NOT stake tokenId 17 for value thats too low", async function () {
      await utils.shouldThrow(stakeInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 500000000000000}));
    });

    it("can stake tokenId 17 for correct value", async function () {
      const valueInTreasury = await web3.eth.getBalance(stakeInstance.address);
      const outstandingShares = await stakeInstance.getTotalOutstandingShares();
      const sharePrice = valueInTreasury / outstandingShares;
      await stakeInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: sharePrice + 100000});
    });

    it("should show an treasury value of 0.1", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result > 98999099991099905, true)
    });

    it("should count 2 outstanding share", async function () {
      const result = await stakeInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 2)
    });

    it("should count 1 share for Bob", async function () {
      const result = await stakeInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 1)
    });

    
  });

  describe('When paying out all stakers, it', () => {
    
    it("should show two staking addresses", async function () {
      const result = await stakeInstance.getAllStakerAddresses();
      assert.equal(result.length, 2)
    });

    it("should show an treasury value of 0.1", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result > 98999099991099905, true)
    });
    it("should payout all stakers", async function () {
      const preValue = await web3.eth.getBalance(treasury);
      await stakeInstance.payoutStakers();
      const postValue = await web3.eth.getBalance(treasury);

      assert.equal(postValue - preValue > 990000000000000, true)
    });

    it("should show an empty treasury", async function () {
      const result = await web3.eth.getBalance(stakeInstance.address);
      assert.equal(result, 0)
    });
  });


 
});

