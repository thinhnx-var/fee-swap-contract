# VarMeta Fee MiddleWare Contract
## Info:
- BSC testnet: https://bsc-testnet.bnbchain.org
- VarMetaSwapper Verified @testnet: `0xBdf36430c0F3A4E7A6D8195db48662Eadf076FEd`

- VarMetaSwapper Verified @mainnet: `0x954204ce42eB3521D5EAd42F988A66e5C0A01693`

## Deploy Guideline:
- Install required packages with: `npm i`
- `cp .env.example .env`
- Edit the `.env` file with following details:
    - Replace private key in `PRVKEY`
    - Recheck addresses of router and factory
    - If you want to verify the contract / show the contract's code on bsc scan, you need to provide the `API_KEY` of bsc scan. Simplest way is getting at: [BSC Dashboard](https://bscscan.com/apidashboard)
- Deploy command: `npx hardhat run scripts/deploy_v3.js --network mainnet`
- Verify command: `npx hardhat verify --network mainnet {Contract_Address} {Args1} {Args2} {Args3}`. Which Args1 is Pancake V3 Router, Args2 is Pancake V3 Factory, Args3 is FeePercentage.