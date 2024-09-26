type Token = {
  address: string;
  decimals: number;
  symbol: string;
  name: string;
};

type ActiveIncentive = {
  id: string;
  token: Token;
  amountLeft: number;
  incentiveRate: number;
};

type WhitelistedToken = {
  isWhiteListed: boolean;
  token: Token;
};

type ProductMetadata = {
  name: string;
  logoURI: string;
  url: string;
  description: string;
};

type Metadata = {
  vaultAddress: string;
  receiptTokenAddress: string;
  name: string;
  logoURI: string;
  product: string;
  url: string;
  productMetadata: ProductMetadata;
};

type Validator = {
  id: string;
  logoURI: string;
  name: string;
  Description: string;
  website: string;
  twitter: string;
};

export type BGTVault = {
  id: string;
  vaultAddress: string;
  stakingTokenAddress: string;
  amountStaked: string;
  activeIncentives: ActiveIncentive[];
  vaultWhitelist: {
    whitelistedTokens: WhitelistedToken[];
  };
  metadata: Metadata;
  activeIncentivesInHoney: number;
  activeValidators: Validator[];
  activeValidatorsCount: number;
  bgtInflationCapture: number;
  totalBgtReceived: number;
};
