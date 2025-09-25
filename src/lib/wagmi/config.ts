import { createConfig, http, type CreateConnectorFn } from '@wagmi/core';
import { injected, metaMask, walletConnect } from '@wagmi/connectors';
import { optimismSepolia, type Chain } from '@wagmi/core/chains';
import { http as viemHttp, createPublicClient } from 'viem';

const dappMetadata = {
  name: 'Gildi',
  description: 'Tokenization marketplace for fractional business ownership.',
  url: 'https://gildi.app',
  icons: ['https://gildi.app/favicon.png'],
};

const walletConnectProjectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID;

export const chains = [optimismSepolia] satisfies readonly [Chain, ...Chain[]];

const connectors = [
  metaMask({ dappMetadata }),
  injected({ shimDisconnect: true }),
  ...(walletConnectProjectId
    ? [
        walletConnect({
          projectId: walletConnectProjectId,
          metadata: dappMetadata,
          showQrModal: true,
        }),
      ]
    : []),
] satisfies readonly CreateConnectorFn[];

export const config = createConfig({
  chains,
  connectors,
  transports: {
    [optimismSepolia.id]: http('https://sepolia.optimism.io'),
  },
  multiInjectedProviderDiscovery: true,
});

export const publicClient = createPublicClient({
  chain: optimismSepolia,
  transport: viemHttp('https://sepolia.optimism.io'),
});
