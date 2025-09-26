<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { onMount } from 'svelte';
  import { wallet } from '$lib/wagmi/walletStore';
  import type { WalletState } from '$lib/wagmi/walletStore';
  import { getAvailableBalance, getMarketplaceCurrency, createListing, getFloorPrice } from '$lib/contracts/exchange';
  import type { Address } from 'viem';

  export let open = false;
  export let releaseId: bigint; // aka tokenId

  const dispatch = createEventDispatcher();

  let walletState: WalletState | undefined;
  $: walletState = $wallet as WalletState;
  $: account = walletState?.address as Address | undefined;

  let available: bigint | undefined;
  let marketplaceCurrency: Address | undefined;
  let floorPriceCents: bigint | undefined;

  // Form fields
  let quantityStr = '';
  let priceUsdStr = '';
  let submitting = false;
  let errorMsg: string | undefined;

  async function hydrate() {
    errorMsg = undefined;
    if (!account) return;
    try {
      [available, marketplaceCurrency, floorPriceCents] = await Promise.all([
        getAvailableBalance(releaseId, account),
        getMarketplaceCurrency(),
        getFloorPrice(releaseId),
      ]);
      if (!priceUsdStr && floorPriceCents) {
        // set default price to floor (in USD)
        priceUsdStr = (Number(floorPriceCents) / 100).toString();
      }
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Failed to load market data';
    }
  }

  $: if (open) {
    // refresh when opening
    hydrate();
  }

  function close() {
    open = false;
    dispatch('close');
  }

  function parseBigintFromDecimalString(value: string, decimals: number): bigint | undefined {
    if (!value) return undefined;
    const n = Number(value);
    if (!isFinite(n) || n < 0) return undefined;
    return BigInt(Math.round(n * 10 ** decimals));
  }

  async function onSubmit() {
    if (!account || !marketplaceCurrency) return;
    errorMsg = undefined;
    const quantity = BigInt(Number(quantityStr || '0'));
    const priceCents = parseBigintFromDecimalString(priceUsdStr, 2);

    if (!quantity || quantity <= 0n) {
      errorMsg = 'Quantity must be greater than 0';
      return;
    }
    if (!priceCents || priceCents <= 0n) {
      errorMsg = 'Price must be greater than 0';
      return;
    }
    if (available !== undefined && quantity > available) {
      errorMsg = 'Quantity exceeds available balance';
      return;
    }

    submitting = true;
    try {
      await createListing({
        releaseId,
        seller: account,
        pricePerItem: priceCents,
        quantity,
        payoutCurrency: marketplaceCurrency,
        fundsReceiver: account,
      });
      dispatch('created');
      close();
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Transaction failed';
    } finally {
      submitting = false;
    }
  }
</script>

{#if open}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">Create Listing</h3>
        <button class="text-gray-500 hover:text-gray-700" on:click={close}>✕</button>
      </div>

      <div class="space-y-4">
        <div>
          <label for="releaseId" class="block text-sm text-gray-600 mb-1">Release ID</label>
          <div id="releaseId" class="text-gray-900 font-medium">{String(releaseId)}</div>
        </div>

        <div>
          <label for="availableToSell" class="block text-sm text-gray-600 mb-1">Available to Sell</label>
          <div id="availableToSell" class="text-gray-900">{available !== undefined ? String(available) : '—'}</div>
        </div>

        <div>
          <label for="sellQuantity" class="block text-sm text-gray-600 mb-1">Quantity</label>
          <input id="sellQuantity" class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring" type="number" min="0" bind:value={quantityStr} placeholder="0" />
        </div>

        <div>
          <label for="sellPriceUsd" class="block text-sm text-gray-600 mb-1">Price (USD)</label>
          <input id="sellPriceUsd" class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring" type="number" step="0.01" min="0" bind:value={priceUsdStr} placeholder="0.00" />
          {#if floorPriceCents}
            <p class="mt-1 text-xs text-gray-500">Floor: ${(Number(floorPriceCents)/100).toFixed(2)} USD</p>
          {/if}
        </div>

        

        {#if errorMsg}
          <div class="rounded-lg bg-red-50 p-3 text-sm text-red-600">{errorMsg}</div>
        {/if}

        <div class="flex justify-end gap-2 pt-2">
          <button class="rounded-lg border px-4 py-2" on:click={close} disabled={submitting}>Cancel</button>
          <button class="rounded-lg bg-orange-600 px-4 py-2 text-white disabled:opacity-50" on:click|preventDefault={onSubmit} disabled={submitting}>
            {submitting ? 'Submitting…' : 'Create Listing'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
