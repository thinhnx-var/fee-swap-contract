require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */

require('dotenv').config();

module.exports = {
	solidity: {
		compilers: [
			{
				version: "0.8.28",
			},
		],
	},
	settings: {
		evmVersion: "istanbul",
	},
	networks: {
		bsctest: {
			url: "https://bsc-testnet.bnbchain.org",
			// url: "https://rpc-testnet.0g.ai",
			chainId: 97,
			accounts: [process.env.PRVKEY],
			gas: 50000000000,
      		gasPrice: 3000000000,
		},
	},
};