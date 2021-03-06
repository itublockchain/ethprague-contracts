require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.13",
  networks: {
    avalanche: {
      url: `https://api.avax.network/ext/bc/C/rpc`
    },
    fuji: {
      url: `https://api.avax-test.network/ext/bc/C/rpc` 
    }
  }
};