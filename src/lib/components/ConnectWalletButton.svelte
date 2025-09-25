<script lang="ts">
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';
  import { getConnectors, type Connector } from '@wagmi/core';
  import Button from '$lib/components/Button.svelte';
  import { wallet, connectWallet, disconnectWallet } from '$lib/wagmi/walletStore';
  import { config } from '$lib/wagmi/config';

  let isMenuOpen = false;
  let availableConnectors: Connector[] = [];
  let connectingId: string | null = null;

  const shortenAddress = (address: string) =>
    `${address.slice(0, 6)}…${address.slice(address.length - 4)}`;

  onMount(() => {
    if (!browser) return;
    availableConnectors = [...getConnectors(config)];
  });

  const ensureConnectors = () => {
    if (!browser) return;
    if (availableConnectors.length === 0) {
      availableConnectors = [...getConnectors(config)];
    }
  };

  const handleConnect = async (connectorId?: string) => {
    ensureConnectors();
    connectingId = connectorId ?? null;
    await connectWallet(connectorId);
    connectingId = null;
    if (walletState.status === 'connected') {
      isMenuOpen = false;
    }
  };

  const handleDisconnect = async () => {
    isMenuOpen = false;
    await disconnectWallet();
  };

  const handlePrimaryClick = async () => {
    if (!browser) return;
    ensureConnectors();
    if (availableConnectors.length <= 1) {
      const defaultConnector = availableConnectors[0];
      await handleConnect(defaultConnector?.id);
    } else {
      isMenuOpen = !isMenuOpen;
    }
  };

  const handleConnectedMenuToggle = () => {
    ensureConnectors();
    isMenuOpen = !isMenuOpen;
  };

  $: walletState = $wallet;
  $: selectedAddress =
    walletState.status === 'connected' && walletState.address
      ? walletState.address
      : undefined;
  $: showError = walletState.status === 'error' ? walletState.errorMessage : undefined;
</script>

<div class="relative">
  {#if walletState.status === 'connected' && selectedAddress}
    <div class="flex items-center space-x-2">
      <Button variant="outline" size="sm" on:click={handleConnectedMenuToggle}>
        <span class="inline-flex items-center space-x-2">
          <span class="flex h-2 w-2">
            <span class="animate-ping absolute inline-flex h-2 w-2 rounded-full bg-green-400 opacity-75" />
            <span class="relative inline-flex rounded-full h-2 w-2 bg-green-500" />
          </span>
          <span class="font-mono text-sm">{shortenAddress(selectedAddress)}</span>
        </span>
      </Button>

      {#if isMenuOpen}
        <div class="absolute right-0 top-12 w-56 rounded-xl border border-gray-200 bg-white shadow-lg z-50">
          <div class="px-4 py-3 border-b border-gray-100">
            <p class="text-xs text-gray-500 uppercase tracking-wide">Connected wallet</p>
            <p class="mt-1 text-sm font-medium text-gray-900 font-mono">
              {shortenAddress(selectedAddress)}
            </p>
          </div>
          <div class="p-3">
            <Button variant="outline" size="sm" class="w-full" on:click={handleDisconnect}
              >Disconnect</Button
            >
          </div>
        </div>
      {/if}
    </div>
  {:else}
    <div class="flex flex-col items-stretch">
      <Button
        variant="primary"
        size="sm"
        class="whitespace-nowrap"
        disabled={walletState.status === 'connecting'}
        on:click={handlePrimaryClick}
      >
        {#if walletState.status === 'connecting'}
          Connecting…
        {:else}
          Connect Wallet
        {/if}
      </Button>

      {#if isMenuOpen}
        <div class="absolute right-0 top-12 w-64 rounded-xl border border-gray-200 bg-white shadow-lg z-50">
          <div class="px-4 py-3 border-b border-gray-100">
            <p class="text-xs text-gray-500 uppercase tracking-wide">Select wallet</p>
          </div>
          <div class="p-3 space-y-2">
            {#if availableConnectors.length === 0}
              <p class="text-sm text-gray-500">
                No wallet connectors available. Please install a supported wallet.
              </p>
            {:else}
              {#each availableConnectors as connector}
                <Button
                  variant="outline"
                  size="sm"
                  class="w-full justify-start"
                  disabled={walletState.status === 'connecting'}
                  on:click={() => handleConnect(connector.id)}
                >
                  {connector.name}
                  {#if connectingId === connector.id}
                    <span class="ml-auto text-xs text-gray-500">Connecting…</span>
                  {/if}
                </Button>
              {/each}
            {/if}
          </div>
        </div>
      {/if}

      {#if showError}
        <p class="mt-2 text-xs text-red-500">{showError}</p>
      {/if}
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
