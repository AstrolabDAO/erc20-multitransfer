import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deploy, getDeployer, provider, weiToString } from "@astrolabs/hardhat";
import { ITestEnv, SafeContract } from "./types";
import { getAbi, assert, parseCSV } from "./utils";
import { network } from "@astrolabs/hardhat";
import { Provider as MulticallProvider } from "ethcall";
import * as path from "path";
import { BigNumber } from "ethers";
import { defaultAbiCoder } from "ethers/lib/utils";


export async function initTestEnv(testAddresses="dummy-l1-addresses.csv"): Promise<ITestEnv> {

  const filePath = path.join(__dirname, testAddresses);
  const dummyAddresses = parseCSV(filePath);
  const blockNumber = await provider.getBlockNumber();
  console.log(
    `Connected to ${network.name} (id ${network.config.chainId}), block ${blockNumber}`
  );
  const multicallProvider = new MulticallProvider();
  await multicallProvider.init(provider);

  return {
    network,
    provider,
    deployer: (await getDeployer()) as SignerWithAddress,
    token: {} as SafeContract,
    dummyAddresses,
    multicallProvider,
  };
}

export async function deployToken(env: ITestEnv, name: string, symbol: string, decimals: number, owner: string, contractName="ERC20MultiTransferOwnable"): Promise<SafeContract> {
  const contract = await deploy({
    name: contractName,
    contract: contractName,
    verify: true,
    args: [name, symbol, decimals, owner],
  });
  const abi = await getAbi(contractName);
  env.token = await SafeContract.build(contract.address, abi);
  return env.token;
}

export async function mint(env: ITestEnv, to: string, amount: number) {
  const balanceBefore = await env.token.balanceOf(to);
  const tx = await env.token.mint(to, amount).then((tx) => tx.wait());
  const balanceAfter = await env.token.balanceOf(to);
  console.log(`
    Receiver balance: ${weiToString(balanceBefore)} -> ${weiToString(balanceAfter)}`
  );
  assert(balanceAfter.sub(balanceBefore).eq(amount));
}

export async function transfer(env: ITestEnv, to: string, amount: number) {
  const from = await getDeployer() as SignerWithAddress;
  const senderBalanceBefore = await env.token.balanceOf(from.address);
  const receiverBalanceBefore = await env.token.balanceOf(to);
  const tx = await env.token.transfer(to, amount).then((tx) => tx.wait());
  const senderBalanceAfter = await env.token.balanceOf(from.address);
  const balanceAfter = await env.token.balanceOf(to);
  console.log(`
    Sender balance: ${weiToString(senderBalanceBefore)} -> ${weiToString(
    senderBalanceAfter
  )}
    Receivers balance: ${weiToString(receiverBalanceBefore)} -> ${weiToString(
    balanceAfter
  )}`
  );
  assert(balanceAfter.sub(receiverBalanceBefore).eq(amount));
  assert(senderBalanceAfter.eq(senderBalanceBefore.sub(amount)));
}

export async function defaultMultiSend(
  env: ITestEnv,
  receiverCount: number,
  amount: number
) {
  const receivers = env.dummyAddresses.slice(0, receiverCount);
  const amounts = Array(receiverCount).fill(amount);
  return multiSend(env, receivers, amounts);
}

export async function multiSend(
  env: ITestEnv,
  receivers: string[],
  amounts: number[]
) {
  const from = env.deployer;
  const senderBalanceBefore = await env.token.balanceOf(from.address);
  const receiverBalancesBefore = await env.multicallProvider.all(receivers.map((r) => env.token.multi.balanceOf(r))) as BigNumber[];
  const encodedAmounts = defaultAbiCoder.encode(new Array(amounts.length).fill('uint64'), amounts);
  const tx = await env.token
    .multiSend(receivers, encodedAmounts, { gasLimit: 30e6 })
    .then((tx) => tx.wait());
  const senderBalanceAfter = await env.token.balanceOf(from.address);
  const receiverBalancesAfter = await env.multicallProvider.all(receivers.map((r) => env.token.multi.balanceOf(r))) as BigNumber[];
  console.log(`
    Sender balance: ${weiToString(senderBalanceBefore)} -> ${weiToString(
      senderBalanceAfter
    )}
    Receivers balances: ${receiverBalancesBefore.map(weiToString)} -> ${receiverBalancesAfter.map(
      weiToString
    )}`
  );
  const totalSent = amounts.reduce((a, b) => a + b, 0);
  assert(receiverBalancesAfter.map((b, i) => b.sub(receiverBalancesBefore[i]).eq(amounts[i])).every(ok => ok));
  assert(senderBalanceAfter.eq(senderBalanceBefore.sub(totalSent)));
}
