import { BigNumber, Contract, ethers } from "ethers";
import {
  Provider as MulticallProvider,
  Contract as MulticallContract,
} from "ethcall";
import { erc20Abi } from "abitype/abis";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { getDeployer } from "@astrolabs/hardhat";
import { Network } from "hardhat/types";

export interface ITestEnv {
  network: Network;
  deployer: SignerWithAddress;
  token: SafeContract;
  dummyAddresses: string[];
  provider: ethers.providers.JsonRpcProvider;
  multicallProvider: MulticallProvider;
}

export class SafeContract extends Contract {
  public multi: MulticallContract = {} as MulticallContract;
  public sym: string = "";
  public abi: ReadonlyArray<any> | any[] = [];
  public scale: number = 0;
  public weiPerUnit: number = 0;

  constructor(
    address: string,
    abi: ReadonlyArray<any> | any[] = erc20Abi,
    signer: SignerWithAddress | ethers.providers.JsonRpcProvider
  ) {
    super(address, abi, signer);
    this.abi = abi;
  }

  public static async build(
    address: string,
    abi: ReadonlyArray<any> | any[] = erc20Abi,
    signer?: SignerWithAddress
  ): Promise<SafeContract> {
    try {
      signer ||= (await getDeployer()) as SignerWithAddress;
      const c = new SafeContract(address, abi, signer);
      c.multi = new MulticallContract(address, abi as any[]);
      if ("symbol" in c) {
        // c is a token
        c.sym = await c.symbol?.();
        c.scale = await c.decimals?.() || 8;
        c.weiPerUnit = 10 ** c.scale;
      }
      return c;
    } catch (error) {
      throw new Error(`Failed to build contract ${address}: ${error}`);
    }
  }

  public async copy(signer: SignerWithAddress=(this.signer as SignerWithAddress)): Promise<SafeContract> {
    // return Object.assign(this, await SafeContract.build(this.address, this.abi, signer));
    return await SafeContract.build(this.address, this.abi, signer);
  }

  public safe = async (
    fn: string,
    params: any[],
    opts: any = {}
  ): Promise<any> => {
    if (typeof this[fn] != "function")
      throw new Error(`${fn} does not exist on the contract ${this.address}`);
    try {
      await this.callStatic[fn](...params, opts);
    } catch (error) {
      const txData = this.interface.encodeFunctionData(fn, params);
      throw new Error(`${fn} static call failed, tx not sent: ${error}, txData: ${txData}`);
    }
    console.log(`${fn} static call succeeded, sending tx...`);
    return this[fn](...params, opts);
  };

  public toWei = (n: number | bigint | string | BigNumber): BigNumber => {
    return ethers.utils.parseUnits(n.toString(), this.scale);
  };

  public toAmount = (n: number | bigint | string | BigNumber): number => {
    const weiString = ethers.utils.formatUnits(n, this.scale);
    return parseFloat(weiString);
  };
}
