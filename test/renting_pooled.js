const RentingPooled = artifacts.require("RentingPooled");
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
    rentingInstance = await RentingPooled.deployed();
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
      await rentingInstance.setRareblocksContractAddress(instance.address);
    });
  });


  describe('Before staking, it', () => {
    it("cannot call stakeAndPurchaseTreasuryStock, because token is not approved", async function () {
      await utils.shouldThrow(rentingInstance.stakeAndPurchaseTreasuryStock(1, {from: alice, value: 0}));
    });

    it("should show contract is NOT approved by Alice", async function () {
      const result = await instance.isApprovedForAll(alice, rentingInstance.address);
      assert.equal(result, false);
    });

    it("should send let Alice call setApprovalForAll", async function () {
      await instance.setApprovalForAll(rentingInstance.address, true)
    });

    it("should show contract is approved by Alice", async function () {
      const result = await instance.isApprovedForAll(alice, rentingInstance.address);
      assert.equal(result, true);
    });

    it("should show contract is NOT approved by Bob", async function () {
      const result = await instance.isApprovedForAll(bob, rentingInstance.address);
      assert.equal(result, false);
    });

    it("should send let Bob call setApprovalForAll", async function () {
      await instance.setApprovalForAll(rentingInstance.address, true, {from: bob})
    });

    it("should show contract is approved by Bob", async function () {
      const result = await instance.isApprovedForAll(bob, rentingInstance.address);
      assert.equal(result, true);
    });
    


    it("cannot call stakeAndPurchaseTreasuryStock, does not own tokenId 17", async function () {
      await utils.shouldThrow(rentingInstance.stakeAndPurchaseTreasuryStock(17, {from: alice, value: 0}));
    });
  });

  describe('When renting before any passes are staked, it', () => {
    it("should not be able to rent for free", async function () {
      await utils.shouldThrow(rentingInstance.rent());
    });

    it("should not be able to rent by paying", async function () {
      await utils.shouldThrow(rentingInstance.rent({from: renter, value: 100000000000000000}));
    });
  });

  describe('When staking, it', () => {

    it("can stake tokenId 16 for free, because shares are worth 0", async function () {
      await rentingInstance.stakeAndPurchaseTreasuryStock(16, {from: alice, value: 0});
    });

    it("should show that Renting Contract owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, rentingInstance.address);
    });

    it("should count 1 outstanding share", async function () {
      const result = await rentingInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 1)
    });

    it("should count 1 share for Alice", async function () {
      const result = await rentingInstance.getSharesPerWallet(alice);
      assert.equal(BigInt(result), 1)
    });

    it("should show an empty treasury value", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 0)
    });

    it("can stake tokenId 17 by Bob for free, because shares are worth 0", async function () {
      await rentingInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 0});
    });

    it("should show that Renting Contract owns tokenId 17", async function(){
      const result = await instance.ownerOf(17);
      assert.equal(result, rentingInstance.address);
    });

    it("should count 2 outstanding share", async function () {
      const result = await rentingInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 2)
    });

    it("should count 1 share for Bob", async function () {
      const result = await rentingInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 1)
    });
    it("should count 1 share for Alice", async function () {
      const result = await rentingInstance.getSharesPerWallet(alice);
      assert.equal(BigInt(result), 1)
    });

    it("should show an empty treasury value", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 0)
    });

    
    
  });
  

  describe('When unstaking with an empty treasury, it', () => {
    it("should NOT let Bob unstake Alice her pass", async function () {
      await utils.shouldThrow(rentingInstance.unstakeAccessPass(16, {from: bob}));
    });

    it("should return an array length of 1, with tokenId 17 on index 0 for Bob", async function () {
      const result = await rentingInstance.getTokensStakedByAddress(bob);
      assert.equal(result.length, 1)
      assert.equal(BigInt(result[0]), 17)
    });

    it("should let Bob unstake tokenId 17", async function () {
      await rentingInstance.unstakeAccessPass(17, {from: bob});
    });

    it("should return an array length of 0 for Bob", async function () {
      const result = await rentingInstance.getTokensStakedByAddress(bob);
      assert.equal(result.length, 0)
    });

    it("should show that Bob owns tokenId 17", async function(){
      const result = await instance.ownerOf(17);
      assert.equal(result, bob);
    });

    it("should count 1 outstanding share", async function () {
      const result = await rentingInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 1)
    });

    it("should count 0 share for Bob", async function () {
      const result = await rentingInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 0)
    });

    it("should show an empty treasury value", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 0)
    });

    it("should let Bob restake for free", async function () {
      await rentingInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 0});
    });
  });


  describe('When renting, after passes have been staked, it', () => {

    it("should show unactive rental for this wallet", async function () {
      const result = await rentingInstance.isRentActive(renter);
      assert.equal(result, false)
    });

    it("should NOT be able to rent for free", async function () {
      await utils.shouldThrow(rentingInstance.rent({from: renter, value: 0}));
    });

    it("should be able to rent for 1E", async function () {
      const value = 100000000000000000;
      const from = renter;
      await rentingInstance.rent({from, value});
    });

    it("should show a treasury value of 0.1E", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 100000000000000000)
    });

    it("should be NOT able to rent another pass for 1E", async function () {
      const value = 100000000000000000;
      const from = renter;
      await utils.shouldThrow(rentingInstance.rent({from, value}));
    });

    it("should show a treasury value of 0.1E", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 100000000000000000)
    });

    it("should show ACTIVE rental for this wallet", async function () {
      const result = await rentingInstance.isRentActive(renter);
      assert.equal(result, true)
    });
  });

  describe('When unstaking, with a full treasury, it', () => {
    it("should have 1Eth in contract wallet", async function () {
      const result = await web3.eth.getBalance(rentingInstance.address);
      assert.equal(result, 100000000000000000)
    });

    it("should let Bob unstake tokenId 17 and earn his interest", async function () {
      const preValue = await web3.eth.getBalance(bob);
      await rentingInstance.unstakeAccessPass(17, {from: bob});
      const postValue = await web3.eth.getBalance(bob);
      const walletIncreaseForBob = postValue - preValue;
      assert.equal(walletIncreaseForBob/divider > 0.04, true);
    });

    it("should show an treasury value of 0.05", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 50000000000000000n)
    });

    it("should count 1 outstanding share", async function () {
      const result = await rentingInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 1)
    });

    it("should count 0 share for Bob", async function () {
      const result = await rentingInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 0)
    });
  });

  describe('When staking, with a full treasury, it', () => {
    it("can NOT stake tokenId 17, because treasury is not empty", async function () {
      await utils.shouldThrow(rentingInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 0}));
    });

    it("can NOT stake tokenId 17 for value thats too low", async function () {
      await utils.shouldThrow(rentingInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: 500000000000000}));
    });

    it("can stake tokenId 17 for correct value", async function () {
      const valueInTreasury = await rentingInstance.getTotalValueInTreasury();
      const outstandingShares = await rentingInstance.getTotalOutstandingShares();
      const sharePrice = valueInTreasury / outstandingShares;
      await rentingInstance.stakeAndPurchaseTreasuryStock(17, {from: bob, value: sharePrice});
    });

    it("should show an treasury value of 0.1", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 100000000000000000n)
    });

    it("should count 2 outstanding share", async function () {
      const result = await rentingInstance.getTotalOutstandingShares();
      assert.equal(BigInt(result), 2)
    });

    it("should count 1 share for Bob", async function () {
      const result = await rentingInstance.getSharesPerWallet(bob);
      assert.equal(BigInt(result), 1)
    });

    
  });

  describe('When paying out all stakers, it', () => {
    
    it("should show an treasury value of 0.1", async function () {
      const result = await rentingInstance.getAllStakerAddresses();
      console.log(result);
    });

    it("should show an treasury value of 0.1", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 100000000000000000n)
    });
    it("should payout all stakers", async function () {
      const preValue = await web3.eth.getBalance(treasury);
      await rentingInstance.payoutStakers();
      const postValue = await web3.eth.getBalance(treasury);

      assert.equal(postValue - preValue > 990000000000000, true)
    });

    it("should show an empty treasury", async function () {
      const result = await rentingInstance.getTotalValueInTreasury();
      assert.equal(BigInt(result), 0)
    });
  });


  // describe('When unstaking, it', () => {
  //   it("should unstake tokenId 16", async function(){
  //     await rentingInstance.unstakeAccessPass(16);
  //   });

  //   it("should show that Alice owns tokenId 16", async function(){
  //     const result = await instance.ownerOf(16);
  //     assert.equal(result, alice);
  //   });

  //   it("should show that Alice staked 1 tokens", async function(){
  //     const result = await rentingInstance.getTokensStakedByAddress(alice);
  //     assert.equal(result.length, 1);
  //   });

  //   it("should unstake tokenId 15", async function(){
  //     await rentingInstance.unstakeAccessPass(15);
  //   });

  //   it("should NOT be able to unstake tokenId 15", async function(){
  //     await utils.shouldThrow(rentingInstance.unstakeAccessPass(15));
  //   });

  //   it("should show that Alice owns tokenId 15", async function(){
  //     const result = await instance.ownerOf(15);
  //     assert.equal(result, alice);
  //   });

  //   it("should show that Alice staked 0 tokens", async function(){
  //     const result = await rentingInstance.getTokensStakedByAddress(alice);
  //     assert.equal(result.length, 0);
  //   });

  //   it("should NOT be able to unstake tokenId 15", async function(){
  //     await utils.shouldThrow(rentingInstance.unstakeAccessPass(15));
  //   });

  // });
});

