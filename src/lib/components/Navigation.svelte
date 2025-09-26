<script lang="ts">
  import { page } from '$app/stores';
  import ConnectWalletButton from './ConnectWalletButton.svelte';
  import Button from '$lib/components/Button.svelte';
  import { wallet } from '$lib/wagmi/walletStore';
  import { requestAllTokens } from '$lib/contracts/faucet';
  import type { Address } from 'viem';
  import type { WalletState } from '$lib/wagmi/walletStore';
  import { config } from '$lib/wagmi/config';
  import { switchChain } from '@wagmi/core';
  import { optimismSepolia } from 'viem/chains';
  import { toast } from '$lib/stores/toast';

  $: currentPath = $page.url.pathname;
  let walletState: WalletState;
  $: walletState = $wallet;
  let faucetLoading = false;
  let mobileOpen = false;
  // toast-based UX; no inline messages

  async function handleFaucet() {
    // reset
    if (
      !walletState ||
      walletState.status !== 'connected' ||
      !walletState.address
    )
      return;
    try {
      faucetLoading = true;
      // Ensure correct chain
      if (walletState.chainId !== optimismSepolia.id) {
        console.log('Switching chain to Optimism Sepolia...');
        await switchChain(config, { chainId: optimismSepolia.id });
      }
      console.log('Requesting faucet tokens for', walletState.address);
      const receipt = await requestAllTokens(walletState.address as Address);
      const url = `https://sepolia-optimism.etherscan.io/tx/${receipt.transactionHash}`;
      toast.successWithLink('Faucet tokens requested.', url, 'View tx');
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Faucet request failed';
      // Treat user rejection as non-error informational toast
      if (msg.toLowerCase().includes('user rejected')) {
        toast.info('Request cancelled');
      } else {
        toast.error(`Faucet request failed: ${msg}`);
      }
    } finally {
      faucetLoading = false;
    }
  }
</script>

<nav class="bg-white border-b border-gray-200 sticky top-0 z-40">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex justify-between items-center h-16">
      <!-- Logo -->
      <div class="flex items-center">
        <a href="/" class="flex items-center space-x-3">
          <img src="/logo-black.png" alt="Gildi" class="h-8 w-auto" />
        </a>
      </div>

      <!-- Navigation Links -->
      <div class="hidden md:flex items-center space-x-8">
        <a
          href="/"
          class="text-gray-700 hover:text-orange-600 px-3 py-2 text-sm font-medium transition-colors"
          class:text-orange-600={currentPath === '/'}
          class:font-semibold={currentPath === '/'}
        >
          Marketplace
        </a>
        <a
          href="/portfolio"
          class="text-gray-700 hover:text-orange-600 px-3 py-2 text-sm font-medium transition-colors"
          class:text-orange-600={currentPath === '/portfolio'}
          class:font-semibold={currentPath === '/portfolio'}
        >
          Portfolio
        </a>
        <div class="flex items-center space-x-2">
          <Button
            variant="secondary"
            size="md"
            on:click={handleFaucet}
            disabled={faucetLoading || walletState?.status !== 'connected'}
          >
            {faucetLoading ? 'Requesting…' : 'Get Faucet Tokens'}
          </Button>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center space-x-4">
        <ConnectWalletButton />
      </div>

      <!-- Mobile menu button -->
      <div class="md:hidden">
        <button
          class="text-gray-700 hover:text-orange-600 focus:outline-none focus:text-orange-600"
          aria-label="Toggle navigation menu"
          aria-expanded={mobileOpen}
          aria-controls="mobile-menu"
          on:click={() => (mobileOpen = !mobileOpen)}
        >
          {#if !mobileOpen}
            <svg
              class="h-6 w-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 6h16M4 12h16M4 18h16"
              />
            </svg>
          {:else}
            <svg
              class="h-6 w-6"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          {/if}
        </button>
      </div>
    </div>
    {#if mobileOpen}
      <!-- Mobile dropdown menu -->
      <div id="mobile-menu" class="md:hidden border-t border-gray-200">
        <div class="py-3 space-y-1">
          <a
            href="/"
            class="block px-3 py-2 text-base font-medium text-gray-700 hover:text-orange-600 hover:bg-gray-50 rounded-md"
            class:text-orange-600={currentPath === '/'}
            class:font-semibold={currentPath === '/'}
            on:click={() => (mobileOpen = false)}
            >Marketplace</a
          >
          <a
            href="/portfolio"
            class="block px-3 py-2 text-base font-medium text-gray-700 hover:text-orange-600 hover:bg-gray-50 rounded-md"
            class:text-orange-600={currentPath === '/portfolio'}
            class:font-semibold={currentPath === '/portfolio'}
            on:click={() => (mobileOpen = false)}
            >Portfolio</a
          >
          <div class="px-3 pt-1">
            <Button
              variant="secondary"
              size="md"
              class="w-full"
              on:click={async () => {
                await handleFaucet();
                mobileOpen = false;
              }}
              disabled={faucetLoading || walletState?.status !== 'connected'}
            >
              {faucetLoading ? 'Requesting…' : 'Get Faucet Tokens'}
            </Button>
          </div>
        </div>
      </div>
    {/if}
  </div>
</nav>
