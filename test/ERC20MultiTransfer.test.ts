import * as dotenv from "dotenv";

dotenv.config({ override: true });

import {
  ethers,
  network,
  setBalances,
  weiToString
} from "@astrolabs/hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ITestEnv } from "./types";
import { defaultMultiSend, deployToken, initTestEnv, mint, transfer } from "./flows";

let env: ITestEnv;

describe("swapper.contract.test", function () {
  this.beforeAll(async function () {
    // await resetNetwork(network, 250); // fantom
    // this.snapshotId = await this.provider.send("evm_snapshot", []);
    env = await initTestEnv();
    await deployToken(env, "Astrolab Dust", "DUST", 18, env.deployer.address);
    await mint(env, env.deployer.address, 1e8);
  });

  this.beforeEach(async function () {
    if (network.name.includes("tenderly")) {
      const addresses = (await ethers.getSigners()).map(
        (s: SignerWithAddress) => s.address
      );
      const result = await setBalances(weiToString(1e23), ...addresses);
    }
  });

  describe(`Airdrop bombing`, function () {
    // beforeEach(async function () { await changeNetwork(networkSlug); });
    it(`Transfer to 1 dummy`, async () => transfer(env, env.dummyAddresses[0], 100));
    it(`MultiSend to 1 dummies`, async () => defaultMultiSend(env, 1, 100));
    it(`MultiSend to 2 dummies`, async () => defaultMultiSend(env, 2, 100));
    it(`MultiSend to 10 dummies`, async () => defaultMultiSend(env, 10, 100));
    it(`MultiSend to 100 dummies`, async () => defaultMultiSend(env, 100, 100));
    it(`MultiSend to 500 dummies`, async () => defaultMultiSend(env, 500, 500));
    it(`MultiSend to 1k dummies`, async () => defaultMultiSend(env, 1000, 100));
    it(`MultiSend to 2k dummies`, async () => defaultMultiSend(env, 2000, 100));
    it(`MultiSend to 3k dummies`, async () => defaultMultiSend(env, 3000, 100));
    // it(`MultiSend to 4k dummies`, async () => defaultMultiSend(env, 4000, 100));
    // it(`MultiSend to 5k dummies`, async () => defaultMultiSend(env, 5000, 100));
    // it(`MultiSend to 10k dummies`, async () => defaultMultiSend(env, 10000, 100));
  });
});
