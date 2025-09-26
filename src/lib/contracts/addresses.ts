import {
  exchangeAbi,
  orderBookAbi,
  managerAbi,
  faucetAbi,
  aggregatorAbi,
  shareTokenAbi,
  erc20Abi,
} from '../../generated';

export const ADDRESSES = {
  exchange: '0xAAb699BDaa41345d670Ef68FA513fab34349c8BC',
  orderBook: '0xFb2F53a9241AD33Fe308a538f9eD1936Cd53a372',
  manager: '0xa90A0E02c84B351cAa255EA089865B31AEe569Fb',
  faucet: '0xA3405Fd34168f3ea8E3330fad72d03BA1cbdF258',
  aggregator: '0x4Bb0652097B8604c402C2aff636027A1BEB07bAB',
  shareToken: '0x22013a827d7534Ce93a6fB341C1F91a9F0973139',
  tokens: {
    mockWETH: '0x44dF2B9818CBFA04CF3f5aa916CE39De9d8E32bB',
    // mockRUST: '0xe6A3d2959974A47a6CaaC9a5a899324DEEa0e0c0',
    mockUSDC: '0x23Bd327a5C8f5D7bb9A7854985Bacf93fbb739Ec',
  },
} as const;

// ABIs
export const ExchangeAbi = exchangeAbi;
export const OrderBookAbi = orderBookAbi;
export const ManagerAbi = managerAbi;
export const FaucetAbi = faucetAbi;
export const AggregatorAbi = aggregatorAbi;
export const ShareTokenAbi = shareTokenAbi;
export const Erc20Abi = erc20Abi;
