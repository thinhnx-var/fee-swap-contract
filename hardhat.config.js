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
		evmVersion: "paris",
	},
	networks: {
		bsctest: {
			url: "https://bsc-testnet.bnbchain.org",
			// url: "https://bsc-testnet-dataseed.bnbchain.org",
			chainId: 97,
			accounts: [process.env.PRVKEY],
			// Total Cost (in BNB) = gas * gasPrice / 10^18.
			gas: 500000000000,
      		gasPrice: 3000000000,
		},
	},
};

