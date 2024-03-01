import { BigNumber, ethers } from 'ethers';
import { keccak256 } from 'ethers/lib/utils';
import * as fs from 'fs';
import { artifacts } from 'hardhat';

export const BALANCE_SLOT_SEED = Buffer.from("87a211a2".padEnd(64, "0"), "hex");

// encode the amounts into a hex string with 8 bytes per uint64
// defaultAbiCoder.encode(new Array(amounts.length).fill('uint64'), amounts)
export const encodeUint64Amounts = (amounts: number[]) => {
  const base = amounts.map(amount =>
    ethers.utils.hexZeroPad(ethers.utils.hexlify(amount), 8).slice(2)).join('');
  const left = base.length % 64;
  return "0x" + (left ? base.padEnd(base.length + 64 - left, '0') : base);
}

export const computeBalanceSlot = (address: string): BigNumber => {
  const balanceSlotSeed = BALANCE_SLOT_SEED;
  const addressBuffer = Buffer.from(address.slice(2), "hex");
  let slotBuffer = Buffer.alloc(32);
  // Copy the last 8 bytes of the receiver address to the start of dataToHash
  addressBuffer.copy(slotBuffer, 0, 12, 20);
  // Then copy the first 24 bytes of the slot seed right after
  balanceSlotSeed.copy(slotBuffer, 8, 0, 24);
  return BigNumber.from(keccak256(slotBuffer));
}

// Function to parse CSV file
export function parseCSV(filePath: string, rowDelimiter = '\n', colDelimiter = ','): any[] {
  const data = fs.readFileSync(filePath, 'utf8');
  const rows = data.trim().split(rowDelimiter);
  const nCols = (rows[0]?.match(new RegExp(colDelimiter, 'g'))?.length || 0) + 1;
  return nCols > 1 ? rows.map(row => row.split(colDelimiter)) : rows;
}

export function assert(condition: any, message?: string) {
  if (!condition) {
    throw new Error(message || "Assertion failed");
  }
}

export async function getAbi(name: string) {
  const contractArtifact = await artifacts.readArtifact(name);
  return contractArtifact.abi;
}
