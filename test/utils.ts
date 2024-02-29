import * as fs from 'fs';
import { artifacts } from 'hardhat';

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
