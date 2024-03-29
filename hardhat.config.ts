import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";

import { config } from "@astrolabs/hardhat/dist/hardhat.config";

config.solidity!.compilers = [
  {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: false,
      evmVersion: `paris`
    },
  },
];

config.paths = {
  // registry
  interfaces: "../registry/interfaces",
  abis: "../registry/abis",
  registry: "../registry",
  // tmp build files
  artifacts: "./artifacts",
  cache: "./cache",
  // local sources
  sources: "./src",
  tests: "./test/integration",
} as any;

export default config;
