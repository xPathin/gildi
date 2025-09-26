import { defineConfig } from '@wagmi/cli';

import Erc20AbiJson from './src/abi/ERC20.json';
import ExchangeAbiJson from './src/abi/GildiExchange.json';
import OrderBookAbiJson from './src/abi/GildiExchangeOrderBook.json';
import ManagerAbiJson from './src/abi/GildiManager.json';
import FaucetAbiJson from './src/abi/MockTokenFaucet.json';
import AggregatorAbiJson from './src/abi/GildiExchangePaymentAggregator.json';
import ShareTokenAbiJson from './src/abi/GildiShareToken.json';
import { Abi } from 'viem';

export default defineConfig({
  out: 'src/generated.ts',
  contracts: [
    {
      name: 'ERC20',
      abi: Erc20AbiJson as Abi,
    },
    {
      name: 'Exchange',
      abi: ExchangeAbiJson as Abi,
    },
    {
      name: 'OrderBook',
      abi: OrderBookAbiJson as Abi,
    },
    {
      name: 'Manager',
      abi: ManagerAbiJson as Abi,
    },
    {
      name: 'Faucet',
      abi: FaucetAbiJson as Abi,
    },
    {
      name: 'Aggregator',
      abi: AggregatorAbiJson as Abi,
    },
    {
      name: 'ShareToken',
      abi: ShareTokenAbiJson as Abi,
    },
  ],
  plugins: [],
});
