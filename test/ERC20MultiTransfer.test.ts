import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ override: true });

import {
  changeNetwork,
  deploy,
  ethers,
  getDeployer,
  network,
  setBalances,
  weiToString
} from "@astrolabs/hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, Contract } from "ethers";
import { parseCSV } from "./utils";

let networkSlug = "tenderly";
let maxTopup = BigNumber.from(weiToString(5 * 1e18));
let blockNumber: number;
let deployer: SignerWithAddress;
let provider = ethers.provider;
let receivers: string[] = [];
let token: Contract;

describe("swapper.contract.test", function () {
  this.beforeAll(async function () {
    // await resetNetwork(network, 250); // fantom
    // this.snapshotId = await this.provider.send("evm_snapshot", []);
    blockNumber = await provider.getBlockNumber();
    deployer = (await getDeployer()) as any;
    token = await deploy({
      name: "DUST",
      contract: "ERC20MultiTransferOwnable",
      verify: true,
      args: ["Astrolab Dust", "DUST", 18, deployer.address],
    });
    console.log(
      `Connected to ${network.name} (id ${network.config.chainId}), block ${blockNumber}`
    );
    const filePath = path.join(__dirname, "dummy-l1-addresses.csv");
    receivers = parseCSV(filePath);
  });

  this.beforeEach(async function () {
    if (network.name.includes("tenderly")) {
      const addresses = (await ethers.getSigners()).map(
        (s: SignerWithAddress) => s.address
      );
      const result = await setBalances(weiToString(1e23), ...addresses);
    } else if (network.name.includes("hardhat")) {
      await changeNetwork(networkSlug);
    }
  });

  describe(`Airdrop bombing`, function () {
    // beforeEach(async function () { await changeNetwork(networkSlug); });
    it(`Mint 1m tokens to self (deployer)`, async function () {
      const tx = await token.mint(deployer.address, 1e8).then((tx) => tx.wait());
    });
    it(`MultiSend to 2 dummies`, async function () {
      const tx = await token
        .multiSend(receivers.slice(0, 2), Array(2).fill(100), { gasLimit: 5e6 })
        .then((tx) => tx.wait());
    });
    // it(`MultiSend to 10 dummies`, async function () {
    //   const tx = await token
    //     .multiSend(receivers.slice(0, 10), Array(10).fill(100))
    //     .then((tx) => tx.wait());
    // });
    // it(`MultiSend to 100 dummies`, async function () {
    //   const tx = await token
    //     .multiSend(receivers.slice(0, 100), Array(100).fill(100))
    //     .then((tx) => tx.wait());
    // });
    // it(`MultiSend to 1k dummies`, async function () {
    //   const tx = await token
    //     .multiSend(receivers, Array(1000).fill(100))
    //     .then((tx) => tx.wait());
    // });
    // it(`MultiSend to 5k dummies`, async function () {
    //   const tx = await token
    //     .multiSend(receivers.slice(0, 5000), Array(5000).fill(100))
    //     .then((tx) => tx.wait());
    // });
    // it(`MultiSend to 10k dummies`, async function () {
    //   const tx = await token
    //     .multiSend(receivers.slice(0, 10000), Array(10000).fill(100))
    //     .then((tx) => tx.wait());
    // });
    // it(`MultiSend to 20k dummies`, async function () {
    //   const tx = await token
    //     .multiSend(receivers.slice(0, 20000), Array(2000).fill(100))
    //     .then((tx) => tx.wait());
    // });
  });
});
