<script lang="ts">
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';
  import Button from '$lib/components/Button.svelte';
  import {
    wallet,
    connectWallet,
    disconnectWallet,
  } from '$lib/wagmi/walletStore';
  import { openAppKit } from '$lib/wagmi/config';

  let isMenuOpen = false; // only for connected menu

  const shortenAddress = (address: string) =>
    `${address.slice(0, 6)}…${address.slice(address.length - 4)}`;

  onMount(() => {
    if (!browser) return;
  });

  const handleConnect = async () => {
    // If a previous attempt is stuck, reset before opening the modal again
    if (walletState.status === 'connecting') {
      await disconnectWallet();
    }
    // Try AppKit modal first (shows Rabby/MetaMask/WalletConnect)
    if (openAppKit()) return;
    // Fallback: wagmi store connect (will prefer WalletConnect or injected)
    await connectWallet();
  };

  const handleDisconnect = async () => {
    isMenuOpen = false;
    await disconnectWallet();
  };

  const handlePrimaryClick = async () => {
    if (!browser) return;
    await handleConnect();
  };

  const handleConnectedMenuToggle = () => {
    isMenuOpen = !isMenuOpen;
  };

  $: walletState = $wallet;
  $: selectedAddress =
    walletState.status === 'connected' && walletState.address
      ? walletState.address
      : undefined;
  $: showError = undefined; // errors are shown as toasts globally
</script>

<div class="relative">
  {#if walletState.status === 'connected' && selectedAddress}
    <div class="flex items-center space-x-2">
      <Button variant="outline" size="sm" on:click={handleConnectedMenuToggle}>
        <span class="inline-flex items-center space-x-2">
          <span class="flex h-2 w-2">
            <span
              class="animate-ping absolute inline-flex h-2 w-2 rounded-full bg-green-400 opacity-75"
            ></span>
            <span class="relative inline-flex rounded-full h-2 w-2 bg-green-500"
            ></span>
          </span>
          <span class="font-mono text-sm"
            >{shortenAddress(selectedAddress)}</span
          >
        </span>
      </Button>

      {#if isMenuOpen}
        <div
          class="absolute right-0 top-12 w-56 rounded-xl border border-gray-200 bg-white shadow-lg z-50"
        >
          <div class="px-4 py-3 border-b border-gray-100">
            <p class="text-xs text-gray-500 uppercase tracking-wide">
              Connected wallet
            </p>
            <p class="mt-1 text-sm font-medium text-gray-900 font-mono">
              {shortenAddress(selectedAddress)}
            </p>
          </div>
          <div class="p-3">
            <Button
              variant="outline"
              size="sm"
              class="w-full"
              on:click={handleDisconnect}>Disconnect</Button
            >
          </div>
        </div>
      {/if}
    </div>
  {:else}
    <div class="flex items-stretch space-x-2">
      <!-- Old look button that opens AppKit modal under the hood -->
      <Button
        variant="primary"
        size="sm"
        class="whitespace-nowrap"
        on:click={() => connectWallet('injected')}
      >
        Connect Wallet
      </Button>
    </div>
  {/if}
</div>

<style>
  .animate-ping {
    animation: ping 1s cubic-bezier(0, 0, 0.2, 1) infinite;
  }

  @keyframes ping {
    75%,
    100% {
      transform: scale(2);
      opacity: 0;
    }
  }
</style>
