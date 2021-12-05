require("@nomiclabs/hardhat-waffle");
require('@nomiclabs/hardhat-ethers');
require("@nomiclabs/hardhat-etherscan");
import DELPOY_CONFIG from './deploy.config';

// Replace this private key with your Ropsten account private key
// To export your private key from Metamask, open Metamask and
// go to Account Details > Export Private Key
// Be aware of NEVER putting real Ether into testing accounts
const PRIVATE_KEY = DELPOY_CONFIG.PRIVATE_KEY;

module.exports = {
  solidity: "0.8.0",
  networks: {
    bsc: {
      url: 'https://bsc-dataseed1.binance.org/',
      accounts: [`0x${PRIVATE_KEY}`],
    },
    bsctestnet: {
      url: 'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: [`0x${PRIVATE_KEY}`],
    }
  },
  etherscan: {
    apiKey: DELPOY_CONFIG.apiKey
  }
};
