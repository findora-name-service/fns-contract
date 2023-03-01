import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import * as fs from 'fs';

// const secretPath = path.resolve(__dirname, '.secret');
const mnemonic = fs.readFileSync('.secret').toString().trim();

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
    },
    main: {
      url: "https://prod-mainnet.prod.findora.org:8545",
      chainId:2152,
      accounts: [mnemonic]
    }
  },
  solidity: {
    version: "0.8.10",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: './build/cache',
    artifacts: './build/artifacts',
  },
  mocha: {
    timeout: 20000
  },
  gasReporter: {
    currency: 'USD',
    enabled: true,
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: '<api-key>',
  }
}

