<script lang="ts">
  import { wallet } from '$lib/wagmi/walletStore';
  import type { WalletState } from '$lib/wagmi/walletStore';
  import Button from '$lib/components/Button.svelte';
  import { getListingsOfSeller, cancelListing, type Listing } from '$lib/contracts/exchange';
  import ModifyListingModal from './ModifyListingModal.svelte';
  import { businesses } from '$lib/data/businesses';
  import type { Address } from 'viem';

  export let seller: Address | undefined = undefined;

  let walletState: WalletState | undefined;
  $: walletState = $wallet as WalletState;
  let address: Address | undefined;
  $: address = seller ?? (walletState?.address as Address | undefined);

  let listings: Listing[] = [];
  let loading = false;
  let errorMsg: string | undefined;

  let modifyOpen = false;
  let selected: Listing | undefined;

  function formatUsdCents(value: bigint) {
    return `$${(Number(value) / 100).toFixed(2)}`;
  }

  function businessForReleaseId(releaseId: bigint) {
    return businesses.find((b) => b.tokenId === releaseId);
  }

  async function refresh() {
    if (!address) return;
    loading = true;
    errorMsg = undefined;
    try {
      const all = await getListingsOfSeller(address);
      listings = all.filter((l) => l.quantity > 0n);
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Failed to load listings';
      listings = [];
    } finally {
      loading = false;
    }
  }

  $: if (address) refresh();

  async function onCancel(id: bigint) {
    try {
      await cancelListing(id);
      await refresh();
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Cancel failed';
    }
  }
</script>

<div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
  <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
    <h2 class="text-lg font-semibold text-gray-900">My Listings</h2>
    {#if loading}
      <span class="text-sm text-gray-500">Loading…</span>
    {/if}
  </div>

  {#if errorMsg}
    <div class="px-6 py-3 text-sm text-red-600 bg-red-50">{errorMsg}</div>
  {/if}

  {#if listings.length === 0}
    <div class="p-6 text-center text-gray-600">No active listings</div>
  {:else}
    <!-- Desktop Table -->
    <div class="hidden md:block overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Company</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Price</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Quantity</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          {#each listings as l}
            {#key String(l.id)}
              <tr class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  {#if businessForReleaseId(l.releaseId)}
                    <div class="flex items-center">
                      <div class="w-10 h-10 bg-orange-50 rounded-lg flex items-center justify-center text-lg mr-3">{businessForReleaseId(l.releaseId)!.logo}</div>
                      <div>
                        <div class="text-sm font-medium text-gray-900">{businessForReleaseId(l.releaseId)!.name}</div>
                        <div class="text-sm text-gray-500">{businessForReleaseId(l.releaseId)!.industry}</div>
                      </div>
                    </div>
                  {:else}
                    <span class="text-sm text-gray-500">Unknown</span>
                  {/if}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{formatUsdCents(l.pricePerItem)}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{String(l.quantity)}</td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <div class="flex space-x-2">
                    <Button variant="outline" size="sm" on:click={() => { selected = l; modifyOpen = true; }}>Modify</Button>
                    <Button variant="danger" size="sm" on:click={() => onCancel(l.id)}>Cancel</Button>
                  </div>
                </td>
              </tr>
            {/key}
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Mobile Cards -->
    <div class="md:hidden">
      {#each listings as l}
        <div class="p-6 border-b border-gray-200 last:border-b-0">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-orange-50 rounded-lg flex items-center justify-center text-lg mr-3">
                {#if businessForReleaseId(l.releaseId)}
                  {businessForReleaseId(l.releaseId)!.logo}
                {/if}
              </div>
              <div>
                <div class="font-medium text-gray-900">{businessForReleaseId(l.releaseId)?.name ?? 'Unknown'}</div>
                <div class="text-sm text-gray-500">{String(l.quantity)} shares</div>
              </div>
            </div>
            <div class="text-right">
              <div class="font-semibold text-gray-900">{formatUsdCents(l.pricePerItem)}</div>
            </div>
          </div>
          <div class="flex space-x-2">
            <Button variant="outline" size="sm" class="flex-1" on:click={() => { selected = l; modifyOpen = true; }}>Modify</Button>
            <Button variant="danger" size="sm" class="flex-1" on:click={() => onCancel(l.id)}>Cancel</Button>
          </div>
        </div>
      {/each}
    </div>
  {/if}

  <ModifyListingModal bind:open={modifyOpen} listing={selected} on:modified={() => refresh()} />
</div>
