const { ethers } = require("hardhat");

async function cancelPendingTransaction() {
  const [signer] = await ethers.getSigners();
  const address = await signer.getAddress();
  const provider = ethers.provider;

  // Get the pending nonce
  const pendingNonce = await provider.getTransactionCount(address, "pending");

  console.log(`Pending nonce: ${pendingNonce}`);

  // Create a transaction to cancel the pending one (send to self with 0 value)
  const tx = {
    to: address, // Send to the same address to cancel
    value: ethers.parseEther("0"), // 0 ETH
    nonce: pendingNonce, // Use the same nonce as the pending transaction
    gasLimit: 21000, // Standard gas limit
    gasPrice: (await ethers.parseUnits("3000000000", "wei")), // Double the current gas price to ensure replacement
  };

  // Send the cancellation transaction
  const cancelTx = await signer.sendTransaction(tx);
  console.log("Cancellation transaction sent, hash:", cancelTx.hash);

  // Wait for the transaction to be mined
  const receipt = await cancelTx.wait();
  console.log("Cancellation transaction confirmed, block number:", receipt.blockNumber);


}


cancelPendingTransaction()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });