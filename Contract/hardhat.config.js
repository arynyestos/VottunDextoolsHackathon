require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    rsk: {
      url: process.env.RSK_RPC_URL,
      chainId: 31,
      accounts: [process.env.PRIVATE_KEY]
    }
  },
  etherscan: {
    apiKey: process.env.BLOCKSCOUT_API_KEY,
    customChains: [
      {
        network: "rsk",
        chainId: 31,
        urls: {
          apiURL: "https://rootstock-testnet.blockscout.com/api",
          browserURL: "https://rootstock-testnet.blockscout.com"
        }
      }
    ]
  }
};
