import { browser } from '$app/environment';
import { writable, type Readable } from 'svelte/store';
import {
  connect,
  disconnect,
  getAccount,
  getConnectors,
  switchChain,
  watchAccount,
  type Connector,
  type GetAccountReturnType,
  type WatchAccountReturnType,
} from '@wagmi/core';
import { config } from '$lib/wagmi/config';
import { optimismSepolia } from 'viem/chains';

export type WalletStatus =
  | 'idle'
  | 'connecting'
  | 'connected'
  | 'disconnected'
  | 'error';

export interface WalletState {
  status: WalletStatus;
  address?: string;
  connector?: Connector;
  chainId?: number;
  errorMessage?: string;
}

type AccountState = GetAccountReturnType<typeof config>;

const toWalletState = (account: AccountState | null): WalletState => {
  if (!account) {
    return {
      status: 'disconnected',
    } satisfies WalletState;
  }

  return {
    status: account.status === 'connected' ? 'connected' : 'disconnected',
    address: account.address,
    connector: account.connector,
    chainId: account.chainId,
  } satisfies WalletState;
};

const walletStore = writable<WalletState>({ status: 'idle' });

let unwatch: WatchAccountReturnType | undefined;

if (browser) {
  const account = getAccount(config);
  walletStore.set(toWalletState(account));

  unwatch = watchAccount(config, {
    onChange(nextAccount) {
      walletStore.update((state) => {
        const nextState = toWalletState(nextAccount);
        return {
          ...nextState,
          errorMessage: nextState.status === 'connected' ? undefined : state.errorMessage,
        } satisfies WalletState;
      });
    },
  });
}

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    unwatch?.();
  });
}

export const wallet: Readable<WalletState> = {
  subscribe: walletStore.subscribe,
};

const ensureCorrectChain = async () => {
  if (!browser) return;

  const account = getAccount(config);
  if (account?.chainId !== optimismSepolia.id) {
    await switchChain(config, { chainId: optimismSepolia.id });
  }
};

export const connectWallet = async (connectorId?: string) => {
  if (!browser) return;

  const availableConnectors = getConnectors(config);
  const connector = connectorId
    ? availableConnectors.find((item) => item.id === connectorId)
    : availableConnectors[0];

  if (!connector) {
    walletStore.set({
      status: 'error',
      errorMessage: 'No wallet connectors are configured.',
    });
    return;
  }

  walletStore.update((state) => ({ ...state, status: 'connecting', errorMessage: undefined }));

  try {
    await connect(config, { connector, chainId: optimismSepolia.id });
    await ensureCorrectChain();
    walletStore.update((state) => ({
      ...state,
      status: 'connected',
      errorMessage: undefined,
    }));
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Unable to connect wallet. Please try again.';
    walletStore.set({ status: 'error', errorMessage: message });
  }
};

export const disconnectWallet = async () => {
  if (!browser) return;

  try {
    await disconnect(config);
    walletStore.set({ status: 'disconnected' });
  } catch (error) {
    const message =
      error instanceof Error
        ? error.message
        : 'Unable to disconnect wallet. Please try again.';
    walletStore.set({ status: 'error', errorMessage: message });
  }
};
