// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  // Deploy Campaign
  const Campaign = await hre.ethers.getContractFactory("ChainFundHubCampaign");
  const campaign = await Campaign.deploy();
  await campaign.deployed();
  console.log("Campaign deployed to:", campaign.address);

  // Deploy Finance
  const Finance = await hre.ethers.getContractFactory("ChainFundHubFinance");
  const finance = await Finance.deploy();
  await finance.deployed();
  console.log("Finance deployed to:", finance.address);

  // Deploy User
  const User = await hre.ethers.getContractFactory("ChainFundHubUser");
  const user = await User.deploy();
  await user.deployed();
  console.log("User deployed to:", user.address);

  // Deploy Core
  const Core = await hre.ethers.getContractFactory("ChainFundHubCore");
  const core = await Core.deploy();
  await core.deployed();
  console.log("Core deployed to:", core.address);

  // Setup connections
  await core.setFinanceManager(finance.address);
  await core.setCampaignManager(campaign.address);
  await core.setUserManager(user.address);

  // Grant CORE_ROLE
  await campaign.grantRole(await campaign.CORE_ROLE(), core.address);
  await finance.grantRole(await finance.CORE_ROLE(), core.address);
  await user.grantRole(await user.CORE_ROLE(), core.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});