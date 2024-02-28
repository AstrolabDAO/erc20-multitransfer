import { deployAll } from "@astrolabs/hardhat";

async function main() {
  await deployAll({
    name: "ERC20MultiTransfer",
    contract: "ERC20MultiTransfer",
    verify: true,
    args: [],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
