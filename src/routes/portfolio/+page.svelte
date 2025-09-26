<script lang="ts">
  import { browser } from '$app/environment';
  import { businesses } from '$lib/data/businesses';
  import Button from '$lib/components/Button.svelte';
  import {
    wallet,
    connectWallet,
    disconnectWallet,
  } from '$lib/wagmi/walletStore';
  import type { WalletState } from '$lib/wagmi/walletStore';
  import { publicClient, openAppKit } from '$lib/wagmi/config';
  import { ManagerAbi, ADDRESSES } from '$lib/contracts/addresses';
  import { marketDataFor, type MarketSnapshot } from '$lib/stores/marketData';
  import { toast } from '$lib/stores/toast';
  import { get, type Readable } from 'svelte/store';
  import SellListingModal from '$lib/components/SellListingModal.svelte';
  import MyListings from '$lib/components/MyListings.svelte';

  const GILDI_MANAGER = ADDRESSES.manager;

  // On-chain balances fetched from GildiManager
  let balances: { tokenId: bigint; amount: bigint; lockedAmount: bigint }[] =
    [];
  let loadingBalances = false;
  let loadError: string | undefined;
  let lastLoadedAddress: string | undefined;
  let walletState: WalletState | undefined;

  type PortfolioHoldingVM = {
    businessId: string;
    shares: number;
    purchasePrice: number;
    purchaseDate?: string;
    business: (typeof businesses)[number];
    currentValue: number;
    investedAmount: number;
    gainLoss: number;
    gainLossPercent: number;
  };
  let portfolioWithDetails: PortfolioHoldingVM[] = [];
  // Shared market data stores per business id
  let mdStores: Record<string, Readable<MarketSnapshot>> = {};
  function ensureStoreForBusinessId(
    businessId: string,
    tokenId: bigint,
    bps: bigint
  ) {
    if (!mdStores[businessId]) {
      mdStores[businessId] = marketDataFor(tokenId, bps);
    }
  }

  async function loadPortfolio(address: string) {
    if (!address) return;
    if (lastLoadedAddress === address && balances.length) return;
    loadingBalances = true;
    loadError = undefined;
    try {
      const result = await publicClient.readContract({
        abi: ManagerAbi as any,
        address: GILDI_MANAGER,
        functionName: 'balanceOf',
        args: [address],
      });
      // Expecting: Array<{ tokenId: bigint; amount: bigint; lockedAmount: bigint }>
      balances = (result as any[]).filter(
        (b) => b && typeof b.amount === 'bigint'
      );
      lastLoadedAddress = address;
    } catch (err) {
      loadError =
        err instanceof Error ? err.message : 'Failed to load portfolio';
      // unify toasts for errors
      toast.error(`Portfolio load failed: ${loadError}`);
      balances = [];
    } finally {
      loadingBalances = false;
    }
  }

  // When wallet connects, fetch balances
  $: if (
    browser &&
    walletState?.status === 'connected' &&
    walletState?.address
  ) {
    // Fire and forget
    loadPortfolio(walletState.address);
  }

  // Build portfolio view model from balances and static business data (by tokenId)
  $: portfolioWithDetails = balances
    .filter((b) => (b?.amount ?? 0n) > 0n)
    .map((b) => {
      const business = businesses.find((item) => item.tokenId === b.tokenId);
      if (!business) return null; // Ignore unknown tokenIds for now
      const shares = Number(b.amount);
      // Ensure we have a store for this business
      ensureStoreForBusinessId(
        business.id,
        b.tokenId,
        business.tokenisedSharesPercentageBps as bigint
      );
      const snap = get(mdStores[business.id]);
      const currentPrice =
        snap?.floorPriceCents != null ? Number(snap.floorPriceCents) / 100 : 0;
      const currentValue = shares * currentPrice;
      // Placeholder: without purchase history, use current price as purchase price so gain/loss = 0
      const purchasePrice = currentPrice;
      const investedAmount = shares * purchasePrice;
      const gainLoss = 0;
      const gainLossPercent = 0;
      return {
        businessId: business.id,
        shares,
        purchasePrice,
        purchaseDate: undefined,
        business,
        currentValue,
        investedAmount,
        gainLoss,
        gainLossPercent,
      } as PortfolioHoldingVM;
    })
    .filter((x): x is PortfolioHoldingVM => x !== null);

  $: totalInvested = portfolioWithDetails.reduce(
    (sum, item) => sum + item.investedAmount,
    0
  );
  $: totalCurrentValue = portfolioWithDetails.reduce(
    (sum, item) => sum + item.currentValue,
    0
  );
  $: totalGainLoss = totalCurrentValue - totalInvested;
  $: totalGainLossPercent =
    totalInvested > 0 ? (totalGainLoss / totalInvested) * 100 : 0;

  function formatCurrency(amount: number | undefined): string {
    if (amount == null || Number.isNaN(amount)) return '—';
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(amount);
  }

  function formatDate(dateString: string): string {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  const handleConnectWallet = async () => {
    if (walletState?.status === 'connecting') {
      await disconnectWallet();
    }
    // Prefer AppKit modal (lists Rabby/MetaMask/WalletConnect)
    if (openAppKit()) return;
    // Fallback to default connect flow
    await connectWallet();
  };

  $: walletState = $wallet as WalletState;
  $: isConnected = walletState?.status === 'connected';
  let activeTab: 'holdings' | 'listings' = 'holdings';
  let sellOpen = false;
  let sellReleaseId: bigint | undefined;
  function openSellModal(releaseId: bigint) {
    sellReleaseId = releaseId;
    sellOpen = true;
  }
  $: walletError =
    walletState?.status === 'error' ? walletState.errorMessage : undefined;
</script>

<svelte:head>
  <title>Portfolio - Gildi</title>
</svelte:head>

{#if isConnected}
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-2">My Portfolio</h1>
      <p class="text-gray-600">Track your investments and performance</p>
    </div>

    <!-- Portfolio Summary -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <div class="bg-white p-6 rounded-xl border border-gray-200">
        <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
          Total Value
        </div>
        <div class="text-2xl font-bold text-gray-900">
          {formatCurrency(totalCurrentValue)}
        </div>
      </div>
      <div class="bg-white p-6 rounded-xl border border-gray-200">
        <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
          Total Invested
        </div>
        <div class="text-2xl font-bold text-gray-900">
          {formatCurrency(totalInvested)}
        </div>
      </div>
      <div class="bg-white p-6 rounded-xl border border-gray-200">
        <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
          Total Gain/Loss
        </div>
        <div
          class="text-2xl font-bold"
          class:text-green-600={totalGainLoss >= 0}
          class:text-red-600={totalGainLoss < 0}
        >
          {formatCurrency(totalGainLoss)}
        </div>
      </div>
      <div class="bg-white p-6 rounded-xl border border-gray-200">
        <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
          Return
        </div>
        <div
          class="text-2xl font-bold"
          class:text-green-600={totalGainLossPercent >= 0}
          class:text-red-600={totalGainLossPercent < 0}
        >
          {totalGainLossPercent >= 0 ? '+' : ''}{totalGainLossPercent.toFixed(
            2
          )}%
        </div>
      </div>
    </div>

    <div class="mb-4 border-b border-gray-200">
      <nav class="-mb-px flex space-x-6" aria-label="Tabs">
        <button
          class="whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium"
          class:border-orange-600={activeTab === 'holdings'}
          class:text-orange-600={activeTab === 'holdings'}
          class:border-transparent={activeTab !== 'holdings'}
          class:text-gray-500={activeTab !== 'holdings'}
          on:click={() => (activeTab = 'holdings')}
        >
          Holdings
        </button>
        <button
          class="whitespace-nowrap border-b-2 px-3 py-2 text-sm font-medium"
          class:border-orange-600={activeTab === 'listings'}
          class:text-orange-600={activeTab === 'listings'}
          class:border-transparent={activeTab !== 'listings'}
          class:text-gray-500={activeTab !== 'listings'}
          on:click={() => (activeTab = 'listings')}
        >
          My Listings
        </button>
      </nav>
    </div>

    {#if activeTab === 'holdings'}
      {#if portfolioWithDetails.length === 0}
        <!-- Empty State -->
        <div
          class="bg-white rounded-xl border border-gray-200 p-12 text-center"
        >
          <div class="flex justify-center mb-6">
            <div class="h-16 w-16 opacity-70 text-orange-600">
              <svg viewBox="0 0 24 24" fill="currentColor" class="h-16 w-16">
                <path
                  d="M12 3l8 4v10l-8 4-8-4V7l8-4zm0 2.2L6 7.5v8.9l6 3 6-3V7.5l-6-2.3z"
                />
              </svg>
            </div>
          </div>
          <h3 class="text-xl font-semibold text-gray-900 mb-2">
            No investments yet
          </h3>
          <p class="text-gray-600 mb-6">
            Start building your portfolio by investing in tokenized business
            shares
          </p>
          <Button variant="primary" href="/">Browse Marketplace</Button>
        </div>
      {:else}
        <!-- Holdings Table -->
        <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-semibold text-gray-900">Holdings</h2>
          </div>

          <!-- Desktop Table -->
          <div class="hidden md:block overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >Company</th
                  >
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >Shares</th
                  >
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >Current Price</th
                  >
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >Gain/Loss</th
                  >
                  <th
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    >Actions</th
                  >
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                {#each portfolioWithDetails as holding}
                  <tr class="hover:bg-gray-50">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="flex items-center">
                        <div
                          class="w-10 h-10 bg-orange-50 rounded-lg flex items-center justify-center text-lg mr-3"
                        >
                          {holding.business.logo}
                        </div>
                        <div>
                          <div class="text-sm font-medium text-gray-900">
                            {holding.business.name}
                          </div>
                          <div class="text-sm text-gray-500">
                            {holding.business.industry}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td
                      class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
                    >
                      {holding.shares}
                    </td>
                    <td
                      class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"
                    >
                      {(() => {
                        const snap = mdStores[holding.business.id]
                          ? get(mdStores[holding.business.id])
                          : undefined;
                        return formatCurrency(
                          snap?.floorPriceCents != null
                            ? Number(snap.floorPriceCents) / 100
                            : undefined
                        );
                      })()}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                      <div class="flex flex-col">
                        <span
                          class:text-green-600={holding.gainLoss >= 0}
                          class:text-red-600={holding.gainLoss < 0}
                        >
                          {formatCurrency(holding.gainLoss)}
                        </span>
                        <span class="text-xs text-gray-500">
                          ({holding.gainLossPercent >= 0
                            ? '+'
                            : ''}{holding.gainLossPercent.toFixed(2)}%)
                        </span>
                      </div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm">
                      <div class="flex space-x-2">
                        <Button
                          variant="outline"
                          size="sm"
                          href={'/business/' + holding.business.id}>View</Button
                        >
                      </div>
                    </td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>

          <!-- Mobile Cards -->
          <div class="md:hidden">
            {#each portfolioWithDetails as holding}
              <div class="p-6 border-b border-gray-200 last:border-b-0">
                <div class="flex items-center justify-between mb-4">
                  <div class="flex items-center">
                    <div
                      class="w-10 h-10 bg-orange-50 rounded-lg flex items-center justify-center text-lg mr-3"
                    >
                      {holding.business.logo}
                    </div>
                    <div>
                      <div class="font-medium text-gray-900">
                        {holding.business.name}
                      </div>
                      <div class="text-sm text-gray-500">
                        {holding.shares} shares
                      </div>
                    </div>
                  </div>
                  <div class="text-right">
                    <div class="font-semibold text-gray-900">
                      {formatCurrency(holding.currentValue)}
                    </div>
                    <div
                      class="text-sm"
                      class:text-green-600={holding.gainLoss >= 0}
                      class:text-red-600={holding.gainLoss < 0}
                    >
                      {holding.gainLossPercent >= 0
                        ? '+'
                        : ''}{holding.gainLossPercent.toFixed(2)}%
                    </div>
                  </div>
                </div>
                <div class="flex justify-between text-sm text-gray-600 mb-3">
                  <span
                    >Avg. Price: {formatCurrency(holding.purchasePrice)}</span
                  >
                  <span>
                    {(() => {
                      const snap = mdStores[holding.business.id]
                        ? get(mdStores[holding.business.id])
                        : undefined;
                      return `Current: ${formatCurrency(snap?.floorPriceCents != null ? Number(snap.floorPriceCents) / 100 : undefined)}`;
                    })()}
                  </span>
                </div>
                <div class="flex space-x-2">
                  <Button
                    variant="outline"
                    size="sm"
                    href={'/business/' + holding.business.id}
                    class="flex-1">View</Button
                  >
                  {#if holding.business.tokenId != null}
                    <Button
                      variant="primary"
                      size="sm"
                      class="flex-1"
                      on:click={() => openSellModal(holding.business.tokenId!)}
                      >Sell</Button
                    >
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    {:else}
      <MyListings />
    {/if}

    {#if sellOpen && sellReleaseId != null}
      <SellListingModal
        bind:open={sellOpen}
        releaseId={sellReleaseId!}
        on:created={() => {}}
      />
    {/if}
  </div>
{:else}
  <div class="min-h-[60vh] flex items-center justify-center px-4">
    <div
      class="max-w-md w-full bg-white border border-gray-200 rounded-2xl p-8 text-center shadow-sm"
    >
      <div
        class="mx-auto mb-6 flex h-12 w-12 items-center justify-center rounded-full bg-orange-100 text-orange-600"
      >
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
            d="M12 11c.5304 0 1.0391-.2107 1.4142-.5858C13.7893 10.0391 14 9.5304 14 9c0-.53043-.2107-1.03914-.5858-1.41421C13.0391 7.21071 12.5304 7 12 7c-.5304 0-1.0391.21071-1.4142.58579C10.2107 7.96086 10 8.46957 10 9c0 .5304.2107 1.0391.5858 1.4142C10.9609 10.7893 11.4696 11 12 11zm0 3c-.5304 0-1.0391.2107-1.4142.5858C10.2107 14.9609 10 15.4696 10 16v1h4v-1c0-.5304-.2107-1.0391-.5858-1.4142C13.0391 14.2107 12.5304 14 12 14zm0 7c-4.4183 0-8-3.5817-8-8 0-4.41828 3.5817-8 8-8 4.4183 0 8 3.58172 8 8 0 4.4183-3.5817 8-8 8z"
          />
        </svg>
      </div>
      <h2 class="text-2xl font-semibold text-gray-900 mb-3">
        Connect your wallet
      </h2>
      <p class="text-gray-600 mb-6">
        Access to the portfolio is restricted to connected wallets. Connect your
        wallet to manage your tokenized business investments.
      </p>
      <div class="flex items-center justify-center space-x-2">
        <Button
          variant="primary"
          class="flex-1"
          on:click={() => connectWallet('injected')}
        >
          Connect Wallet
        </Button>
      </div>
      {#if walletError}
        <p class="mt-3 text-sm text-red-500">{walletError}</p>
      {/if}
    </div>
  </div>
{/if}
