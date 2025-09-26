import { optimismSepolia, type Chain } from '@wagmi/core/chains';
import {
  http as viemHttp,
  webSocket as viemWebSocket,
  createPublicClient,
} from 'viem';
import { createAppKit } from '@reown/appkit';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';

declare global {
  interface Window {
    __appkitInitialized?: boolean;
    __appkit?: ReturnType<typeof createAppKit>;
  }
}

const walletConnectProjectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID as
  | string
  | undefined;

export const chains = [optimismSepolia] satisfies readonly [Chain, ...Chain[]];

const wagmiAdapter = new WagmiAdapter({
  projectId: walletConnectProjectId ?? '',
  networks: chains,
  transports: {
    [optimismSepolia.id]: viemHttp(
      import.meta.env.VITE_OP_SEPOLIA_HTTP || 'https://sepolia.optimism.io'
    ),
  },
  multiInjectedProviderDiscovery: true,
  ssr: true,
});

// Export wagmi config for the rest of the app
export const config = wagmiAdapter.wagmiConfig;

export const publicClient = createPublicClient({
  chain: optimismSepolia,
  transport: import.meta.env.VITE_OP_SEPOLIA_WS
    ? viemWebSocket(import.meta.env.VITE_OP_SEPOLIA_WS)
    : viemHttp(
        import.meta.env.VITE_OP_SEPOLIA_HTTP || 'https://sepolia.optimism.io'
      ),
});

// Initialize Web3Modal once on the client. Safe to call multiple times.
let appKitInstance: ReturnType<typeof createAppKit> | undefined;

export function initAppKit() {
  if (typeof window === 'undefined') return;
  if (window.__appkitInitialized) return;
  const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID as
    | string
    | undefined;
  if (!projectId) return; // no-op if not configured; we handle UX via toasts elsewhere
  appKitInstance = createAppKit({
    adapters: [wagmiAdapter],
    projectId,
    networks: chains,
  });
  window.__appkitInitialized = true;
  window.__appkit = appKitInstance;
}

export function openAppKit(): boolean {
  if (typeof window === 'undefined') return false;
  if (!window.__appkitInitialized) {
    initAppKit();
  }
  const inst = window.__appkit ?? appKitInstance;
  if (inst && typeof inst.open === 'function') {
    inst.open();
    return true;
  }
  return false;
}
