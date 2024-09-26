import {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  parseAbiItem,
  getAddress,
} from "viem";
import { berachainTestnetbArtio } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";

import { HoneyQueenAbi } from "./honeyqueen";
import { HONEYQUEEN_ADDRESS } from "./constants";
import { InfraredVault } from "../types/infrared";

import supabase from "./supabase";

const URL = "https://api.staging.infrared.finance/v2/vaults?page=1&limit=100";

export async function whitelistInfraredGauges() {
  const publicClient = createPublicClient({
    chain: berachainTestnetbArtio,
    transport: http(),
  });

  const walletClient = createWalletClient({
    chain: berachainTestnetbArtio,
    transport: http(),
    account: privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`),
  });

  const response = await fetch(URL);
  const data = await response.json();
  const vaults: InfraredVault[] = data;

  console.log(`Processing ${vaults.length} vaults`);

  for (const vault of vaults) {
    const vaultAddress = getAddress(vault.address);
    const stakingToken = getAddress(vault.stake_token.address);
    console.log(
      `##############################\nProcessing vault ${vaultAddress}`
    );
    // if the vault is already whitelisted, skip it
    const { data: vaultData, error: vaultError } = await supabase
      .from("contracts")
      .select("*")
      .eq("address", vaultAddress);
    const { data: stakingTokenData, error: stakingTokenError } = await supabase
      .from("lp_tokens")
      .select("*")
      .eq("address", stakingToken);

    if (vaultError) {
      console.log(`Error fetching vault ${vaultAddress}`);
      console.log(vaultError);
      continue;
    }
    if (stakingTokenError) {
      console.log(`Error fetching staking token ${stakingToken}`);
      console.log(stakingTokenError);
      continue;
    }
    // skip if the LP token already is in the DB
    if (stakingTokenData.length === 0) {
      // tx successful so we write to database
      // write LP token aka staking token to database
      const { data, error } = await supabase.from("lp_tokens").insert({
        address: stakingToken,
        authorized: true,
        protocol: vault.pool?.protocol ?? "Infrared",
        name: vault.pool?.name ?? vault.stake_token.name,
      });
      if (error) {
        console.log(`Error adding LP token ${stakingToken} to the DB`);
        console.log(error);
        continue;
      }
      console.log(`Added LP token ${stakingToken} to the DB`);
    }
    try {
      // whitelist the vault if it doesn't exist yet
      if (vaultData.length === 0) {
        const transactionHash = await walletClient.writeContract({
          address: HONEYQUEEN_ADDRESS as `0x${string}`,
          abi: HoneyQueenAbi,
          functionName: "setProtocolOfTarget",
          args: [vaultAddress, "Infrared"],
        });
        await publicClient.waitForTransactionReceipt({
          hash: transactionHash,
        });
        console.log(`Whitelisted gauge ${vaultAddress} in HoneyQueen`);
        // write to database
        const { data, error } = await supabase.from("contracts").insert({
          address: vaultAddress,
          is_allowed: true,
          protocol: "Infrared",
          name: `Infrared ${vault.pool?.name ?? vault.stake_token.name}`,
          token_address: stakingToken,
        });
        if (error) {
          console.log(`Error adding ${vaultAddress} to the DB`);
          console.log(error);
          continue;
        }
      }
    } catch (e) {
      console.log(`Could not whitelist gauge ${vaultAddress}`);
      console.log(e);
    }
  }
}

async function main() {
  await whitelistInfraredGauges();
}

main();
