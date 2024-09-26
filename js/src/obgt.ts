import {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  parseAbiItem,
} from "viem";
import { berachainTestnetbArtio } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

import { HoneyQueenAbi } from "./honeyqueen";
import { HONEYQUEEN_ADDRESS } from "./constants";

import supabase from "./supabase";

export async function whitelistBGTGauges() {
  const publicClient = createPublicClient({
    chain: berachainTestnetbArtio,
    transport: http(),
  });

  const walletClient = createWalletClient({
    chain: berachainTestnetbArtio,
    transport: http(),
    account: privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`),
  });

  const fromBlock = 5762n;
  const toBlock = await publicClient.getBlockNumber();
  const finalLogs: any[] = [];
  // go over chunks of blocks
  for (let i = fromBlock; i < toBlock; i += 5000n) {
    const logs = await publicClient.getLogs({
      address: "0x2B6e40f65D82A0cB98795bC7587a71bfa49fBB2B",
      event: parseAbiItem(
        "event VaultCreated(address indexed stakingToken, address indexed vault)"
      ),
      fromBlock: i,
      toBlock: i + 5000n,
    });
    finalLogs.push(...logs);
  }
  for (const log of finalLogs) {
    const vault = log.args.vault;
    const stakingToken = log.args.stakingToken;
    try {
      const transactionHash = await walletClient.writeContract({
        address: HONEYQUEEN_ADDRESS as `0x${string}`,
        abi: HoneyQueenAbi,
        functionName: "setProtocolOfTarget",
        args: [vault, "BGT Station"],
      });
      await publicClient.waitForTransactionReceipt({
        hash: transactionHash,
      });

      // tx successful so we write to database

      // get the name of the token
      const name = await publicClient.readContract({
        address: stakingToken as `0x${string}`,
        abi: parseAbi([`function name() view returns (string)`]),
        functionName: "name",
      });
      // write LP token aka staking token to database
      const { data, error } = await supabase.from("lp_tokens").insert({
        vault: vault,
        staking_token: stakingToken,
        name: name,
      });
      console.log(`Whitelisted gauge ${vault}`);
    } catch (e) {
      console.log(`Could not whitelist gauge ${vault}`);
      console.log(e);
    }
  }
  // whitelist to honeyqueen
  return finalLogs;
}
