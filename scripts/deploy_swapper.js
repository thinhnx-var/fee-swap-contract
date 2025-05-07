const { ethers } = require("hardhat");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();
    const routerV2Address = process.env.PAN_V2;
    console.log("Deploying contracts with the account:", deployer.address);
    const FeeMdw = await ethers.getContractFactory("Swapper");
    const ct = await FeeMdw.deploy(routerV2Address);
    await ct.waitForDeployment();
    console.log("Swapper deployed to:", ct.target);

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