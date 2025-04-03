const { ethers } = require("hardhat");

async function checkPendingNonce() {
  const [signer] = await ethers.getSigners();
  const address = await signer.getAddress();
  const provider = ethers.provider;

  // Get the latest nonce (already mined transactions)
  const latestNonce = await provider.getTransactionCount(address, "latest");
  // Get the pending nonce (includes unmined transactions)
  const pendingNonce = await provider.getTransactionCount(address, "pending");

  console.log(`Latest nonce: ${latestNonce}`);
  console.log(`Pending nonce: ${pendingNonce}`);

  if (pendingNonce > latestNonce) {
    console.log(`There are ${pendingNonce - latestNonce} pending transactions.`);
  } else {
    console.log("No pending transactions.");
  }

  return pendingNonce;
}

checkPendingNonce()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });