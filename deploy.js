const { ethers } = require("hardhat");

async function main() {
  try {
    const [deployer] = await ethers.getSigners();
    const _router = process.env.ROUTER_ADDRESS;
    const _feePercentage = process.env.FEE_PERCENTAGE;
    console.log("Deploying contracts with the account:", deployer.address);
    const FeeMdw = await ethers.getContractFactory("FeeMiddleware");
    const ct = await FeeMdw.deploy(_router, _feePercentage);
    await ct.waitForDeployment();
    console.log("FeeMiddleware deployed to:", ct.target);

        // Deploy ERC-20 Token
        const ERC20Token = await hre.ethers.getContractFactory("VMTS");
        const token = await ERC20Token.deploy(deployer.address, 1000000);
        await token.waitForDeployment();
        console.log("VMTS deployed to:", await token.getAddress());


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