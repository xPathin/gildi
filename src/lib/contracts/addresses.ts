export const ADDRESSES = {
  exchange: '0xAAb699BDaa41345d670Ef68FA513fab34349c8BC',
  orderBook: '0xFb2F53a9241AD33Fe308a538f9eD1936Cd53a372',
  manager: '0xa90A0E02c84B351cAa255EA089865B31AEe569Fb',
  faucet: '0xA3405Fd34168f3ea8E3330fad72d03BA1cbdF258',
  aggregator: '0x4Bb0652097B8604c402C2aff636027A1BEB07bAB',
  tokens: {
    mockWETH: '0x44dF2B9818CBFA04CF3f5aa916CE39De9d8E32bB',
    mockRUST: '0xe6A3d2959974A47a6CaaC9a5a899324DEEa0e0c0',
    mockUSDC: '0x23Bd327a5C8f5D7bb9A7854985Bacf93fbb739Ec',
  },
} as const;

// ABIs
import ExchangeAbiJson from '../../abi/GildiExchange.json';
import OrderBookAbiJson from '../../abi/GildiExchangeOrderBook.json';
import ManagerAbiJson from '../../abi/GildiManager.json';
import FaucetAbiJson from '../../abi/MockTokenFaucet.json';
import AggregatorAbiJson from '../../abi/GildiExchangePaymentAggregator.json';

export const ExchangeAbi = ExchangeAbiJson as any;
export const OrderBookAbi = OrderBookAbiJson as any;
export const ManagerAbi = ManagerAbiJson as any;
export const FaucetAbi = FaucetAbiJson as any;
export const AggregatorAbi = AggregatorAbiJson as any;
