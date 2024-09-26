import { createPublicClient, createWalletClient, http } from "viem";
import { berachainTestnetbArtio } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

import dotenv from "dotenv";
dotenv.config();

import { whitelistBGTGauges } from "./bgt";
import { whitelistInfraredGauges } from "./infrared";

async function main() {
  console.log("Starting ...");
  await whitelistBGTGauges();
  await whitelistInfraredGauges();
  console.log("Done");
}

main();
