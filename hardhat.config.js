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
			// url: "https://bsc-testnet-dataseed.bnbchain.org",
			// url: "https://data-seed-prebsc-1-s1.binance.org:8545",
			chainId: 97,
			accounts: [process.env.PRVKEY],
			// Total Cost (in BNB) = gas * gasPrice / 10^18.
			gas: 50000000,
      		gasPrice: 3000000000,
		},
	},
};

