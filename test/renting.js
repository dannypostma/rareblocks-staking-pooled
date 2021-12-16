const RentingPooled = artifacts.require("RentingPooled");
const RareBlocks = artifacts.require("RareBlocks");
const utils = require("./helpers/utils");

/*
 * uncomment accounts to access the test accounts made available by the
 * Ethereum client
 * See docs: https://www.trufflesuite.com/docs/truffle/testing/writing-tests-in-javascript
 */

contract("RareBlocks", function (accounts) {
  let [alice, bob, charlie] = accounts;
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

    it("should set Rareblocks contract address", async function(){
      await rentingInstance.setRareblocksContractAddress(instance.address);
    });
  });



  describe('When staking, it', () => {

    it("should send 1 NFT from Alice to Renting Contract", async function () {
      const to = rentingInstance.address; // Renting Contract Address
      const from = alice;
      const tokenId = 16;
      const result = await instance.safeTransferFrom(from, to, tokenId);
    });

    it("should stake tokenId 15", async function () {
      const to = rentingInstance.address; // Renting Contract Address
      const from = alice;
      const tokenId = 15;
      await instance.safeTransferFrom(from, to, tokenId);
      
    });

    // Send NFT to Staking contract
    it("should show that Alice staked 2 tokens", async function(){
      const result = await rentingInstance.getTokensStakedByAddress(alice);
      assert.equal(result.length, 2);
    });

    it("should show that Renting Contract owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, rentingInstance.address);
    });
    
  });

  describe('When unstaking, it', () => {
    it("should unstake tokenId 16", async function(){
      await rentingInstance.unstakeAccessPass(16);
    });

    it("should show that Alice owns tokenId 16", async function(){
      const result = await instance.ownerOf(16);
      assert.equal(result, alice);
    });

    it("should show that Alice staked 1 tokens", async function(){
      const result = await rentingInstance.getTokensStakedByAddress(alice);
      assert.equal(result.length, 1);
    });

    it("should unstake tokenId 15", async function(){
      await rentingInstance.unstakeAccessPass(15);
    });

    it("should NOT be able to unstake tokenId 15", async function(){
      await utils.shouldThrow(rentingInstance.unstakeAccessPass(15));
    });

    it("should show that Alice owns tokenId 15", async function(){
      const result = await instance.ownerOf(15);
      assert.equal(result, alice);
    });

    it("should show that Alice staked 0 tokens", async function(){
      const result = await rentingInstance.getTokensStakedByAddress(alice);
      assert.equal(result.length, 0);
    });

    it("should NOT be able to unstake tokenId 15", async function(){
      await utils.shouldThrow(rentingInstance.unstakeAccessPass(15));
    });

  });
});

