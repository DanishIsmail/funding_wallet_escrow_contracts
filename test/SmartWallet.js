const { ethers, upgrades } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe.only("SMART-WaLLET", function () {
  async function deploySmartWalletFixture() {
    const [owner, adminWallet, adminWallet2, userAddr1, userAddr12] =
      await ethers.getSigners();

    const SmartWallet = await ethers.getContractFactory("SmartWallet");
    const smartWallet = await upgrades.deployProxy(
      SmartWallet,
      [adminWallet.address, adminWallet2.address],
      { initializer: "initialize" }
    );
    await smartWallet.waitForDeployment();
    return {
      smartWallet,
      adminWallet,
      adminWallet2,
      owner,
      userAddr1,
      userAddr12,
    };
  }

  describe("Deployment", function () {
    it("Should deploy the SmartWallet contract", async function () {
      const { smartWallet } = await loadFixture(deploySmartWalletFixture);
      console.log("smartWallet deployed to:", await smartWallet.getAddress());

      expect(await smartWallet.getAddress()).to.properAddress;
    });

    it("Deployer should be the owner", async function () {
      const { smartWallet, owner } = await loadFixture(
        deploySmartWalletFixture
      );
      const contractOwner = await smartWallet.owner();
      expect(contractOwner).to.equal(owner.address);
    });
  });
});
