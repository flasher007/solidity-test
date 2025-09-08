const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("VestingVault - requirements", function () {
  const AMT = ethers.parseEther("100");
  const CLIFF = 30 * 24 * 60 * 60;     // 30 days
  const DURATION = 90 * 24 * 60 * 60;  // 90 days

  let owner, alice;
  let token, vault;

  beforeEach(async () => {
    [owner, alice] = await ethers.getSigners();

    const MockToken = await ethers.getContractFactory("MockToken", owner);
    token = await MockToken.deploy();
    await token.waitForDeployment();

    const VestingVault = await ethers.getContractFactory("VestingVault", owner);
    vault = await VestingVault.deploy(token.target);
    await vault.waitForDeployment();

    // Fund vault
    await token.mint(vault.target, AMT);

    // Add grant for Alice
    await vault.connect(owner).addGrant(alice.address, AMT, CLIFF, DURATION);
  });

  it("Nothing vested before cliff", async () => {
    const g = await vault.grants(alice.address);
    const start = Number(g.start);

    await time.increaseTo(start + CLIFF - 1);

    expect(await vault.vestedOf(alice.address)).to.equal(0n);
    await expect(vault.connect(alice).claim())
      .to.be.revertedWithCustomError(vault, "NothingToClaim");
  });

  it("Full amount claimable after duration", async () => {
    const g = await vault.grants(alice.address);
    const start = Number(g.start);

    await time.increaseTo(start + DURATION + 1);

    expect(await vault.vestedOf(alice.address)).to.equal(AMT);

    const before = await token.balanceOf(alice.address);
    // anyone can call claim; tokens go to msg.sender (alice in this case)
    await vault.connect(alice).claim();
    const after = await token.balanceOf(alice.address);

    expect(after - before).to.equal(AMT);
  });
});
