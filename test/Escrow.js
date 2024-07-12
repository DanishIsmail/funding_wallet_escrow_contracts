const { ethers, upgrades } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe.only("ESCROW", function () {
  async function deployEscrowWalletFixture() {
    const [owner, adminWallet, adminWallet2, userAddr1, userAddr12] =
      await ethers.getSigners();

    const ESCROWWALLET = await ethers.getContractFactory("Escrow");
    const escrowWallet = await upgrades.deployProxy(ESCROWWALLET, {
      initializer: "initialize",
    });
    await escrowWallet.waitForDeployment();
    return {
      escrowWallet,
      adminWallet,
      adminWallet2,
      owner,
      userAddr1,
      userAddr12,
    };
  }

  describe("Deployment", function () {
    it("Should deploy the Escrow Wallet contract", async function () {
      const { escrowWallet } = await loadFixture(deployEscrowWalletFixture);
      console.log("escrowWallet deployed to:", await escrowWallet.getAddress());

      expect(await escrowWallet.getAddress()).to.properAddress;
    });

    it("Deployer should be the owner", async function () {
      const { escrowWallet, owner } = await loadFixture(
        deployEscrowWalletFixture
      );
      const contractOwner = await escrowWallet.owner();
      expect(contractOwner).to.equal(owner.address);
    });
  });
});
