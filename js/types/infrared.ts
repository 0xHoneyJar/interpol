type Token = {
  address: string;
  name: string;
  symbol: string;
  decimals: number;
  price?: string;
};

type Pool = {
  protocol: string;
  name: string;
  lp_token_address?: string;
  underlying_tokens: Token[];
  apy: string;
  protocol_logo: string;
  url: string;
};

export type InfraredVault = {
  address: string;
  bera_reward_vault_address: string;
  stake_token: Token;
  pool?: Pool;
  reward_tokens: Token[];
  current_staked_amount: string;
  apy_percentage: string;
};
