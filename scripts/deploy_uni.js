const { ethers } = require("hardhat");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();
    const _pancakeRouter = process.env.PAN_V3;
    console.log("Deploying contracts with the account:", deployer.address);
    const FeeMdw = await ethers.getContractFactory("TempUni");
    const ct = await FeeMdw.deploy(_pancakeRouter);
    await ct.waitForDeployment();
    console.log("TempUni deployed to:", ct.target);

  } catch (error) {
    console.error("Error deploying contract:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });