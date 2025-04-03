require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");

/** @type import('hardhat/config').HardhatUserConfig */

require('dotenv').config();

module.exports = {
	solidity: {
		version: "0.8.20",
		settings: {
		  optimizer: {
			enabled: true,
			runs: 100,
		  },
		  viaIR: true,
		},
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
			gas: 21000,
      		gasPrice: 3000000000,
		},
	},
	etherscan: {
        apiKey: {
            bscTestnet: process.env.BSC_API_KEY // Replace with your BscScan API key
        }
    },
};

//EYPMANQE52732KQSIVN6CBH9BGNGSVRWNT