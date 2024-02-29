import * as fs from 'fs';

// Function to parse CSV file
export function parseCSV(filePath: string, rowDelimiter = '\n', colDelimiter = ','): any[] {
  const data = fs.readFileSync(filePath, 'utf8');
  const rows = data.trim().split(rowDelimiter);
  const nCols = (rows[0]?.match(new RegExp(colDelimiter, 'g'))?.length || 0) + 1;
  return nCols > 1 ? rows.map(row => row.split(colDelimiter)) : rows;
}
