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
import { toast } from '$lib/stores/toast';

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
          errorMessage:
            nextState.status === 'connected' ? undefined : state.errorMessage,
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
  let connector: Connector | undefined;

  // Explicit injected/browser path
  if (connectorId === 'injected' || connectorId === 'browser') {
    connector =
      // Standard injected id
      (availableConnectors.find((c) => c.id === 'injected') as
        | Connector
        | undefined) ||
      // Name heuristics
      (availableConnectors.find(
        (c) =>
          c.name?.toLowerCase()?.includes('injected') ||
          c.name?.toLowerCase()?.includes('browser') ||
          c.name?.toLowerCase()?.includes('rabby')
      ) as Connector | undefined) ||
      // Common MetaMask ids as last resort
      (availableConnectors.find((c) =>
        ['io.metamask', 'metaMask'].includes(c.id)
      ) as Connector | undefined);
  } else if (connectorId) {
    connector = availableConnectors.find((item) => item.id === connectorId);
  } else {
    // Prefer WalletConnect (opens AppKit/WC modal) when no explicit connector is requested
    connector = availableConnectors.find((c) => c.id === 'walletConnect');
  }

  // If WalletConnect isn't available, gracefully fall back to injected/browser wallet
  if (!connector) {
    const injected =
      availableConnectors.find((c) =>
        ['injected', 'io.metamask', 'metaMask'].includes(c.id)
      ) ||
      availableConnectors.find(
        (c) =>
          c.name?.toLowerCase()?.includes('browser') ||
          c.name?.toLowerCase()?.includes('injected') ||
          c.name?.toLowerCase()?.includes('rabby')
      ) ||
      availableConnectors[0];

    if (injected) {
      toast.info('Opening browser wallet (Rabby/MetaMask)');
      connector = injected;
    }
  }

  if (!connector) {
    walletStore.set({
      status: 'error',
      errorMessage: 'No wallet connectors are configured.',
    });
    return;
  }

  walletStore.update((state) => ({
    ...state,
    status: 'connecting',
    errorMessage: undefined,
  }));

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
      error instanceof Error
        ? error.message
        : 'Unable to connect wallet. Please try again.';
    // Normalize UX: show toasts instead of inline error blocks
    const msgLower = message.toLowerCase();
    if (
      msgLower.includes('user rejected') ||
      msgLower.includes('user canceled') ||
      msgLower.includes('user cancelled')
    ) {
      toast.info('Connection cancelled');
    } else if (
      msgLower.includes('missing projectid') ||
      msgLower.includes('project id')
    ) {
      toast.error('WalletConnect is not configured (missing Project ID).');
    } else {
      toast.error(`Wallet connection failed: ${message}`);
    }
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
    toast.error(`Disconnect failed: ${message}`);
    walletStore.set({ status: 'error', errorMessage: message });
  }
};
