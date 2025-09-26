<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import type { Address } from 'viem';
  import { getMarketplaceCurrency, modifyListing, type Listing } from '$lib/contracts/exchange';

  export let open = false;
  export let listing: Listing | undefined;

  const dispatch = createEventDispatcher();

  let marketplaceCurrency: Address | undefined;
  let submitting = false;
  let errorMsg: string | undefined;

  // form fields
  let priceUsdStr = '';
  let quantityStr = '';

  $: if (open && listing) {
    hydrate();
  }

  async function hydrate() {
    errorMsg = undefined;
    try {
      [marketplaceCurrency] = await Promise.all([
        getMarketplaceCurrency(),
      ]);
      if (!priceUsdStr && listing?.pricePerItem) {
        priceUsdStr = (Number(listing.pricePerItem) / 100).toString();
      }
      if (!quantityStr && listing?.quantity !== undefined) {
        quantityStr = String(listing.quantity);
      }
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Failed to load settings';
    }
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
    if (!listing || !marketplaceCurrency) return;
    errorMsg = undefined;
    const newPriceCents = parseBigintFromDecimalString(priceUsdStr, 2);
    const newQty = BigInt(Number(quantityStr || '0'));

    if (!newPriceCents || newPriceCents <= 0n) {
      errorMsg = 'Price must be greater than 0';
      return;
    }
    if (!newQty || newQty <= 0n) {
      errorMsg = 'Quantity must be greater than 0';
      return;
    }

    submitting = true;
    try {
      await modifyListing({
        listingId: listing.id,
        newPricePerItem: newPriceCents,
        newQuantity: newQty,
        payoutCurrency: marketplaceCurrency,
        fundsReceiver: listing.fundsReceiver,
      });
      dispatch('modified', { id: listing.id });
      close();
    } catch (e) {
      errorMsg = e instanceof Error ? e.message : 'Transaction failed';
    } finally {
      submitting = false;
    }
  }
</script>

{#if open && listing}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">Modify Listing #{String(listing.id)}</h3>
        <button class="text-gray-500 hover:text-gray-700" on:click={close}>✕</button>
      </div>

      <div class="space-y-4">
        <div>
          <label for="modifyPriceUsd" class="block text-sm text-gray-600 mb-1">Price (USD)</label>
          <input id="modifyPriceUsd" class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring" type="number" step="0.01" min="0" bind:value={priceUsdStr} />
        </div>
        <div>
          <label for="modifyQuantity" class="block text-sm text-gray-600 mb-1">Quantity</label>
          <input id="modifyQuantity" class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring" type="number" min="0" bind:value={quantityStr} />
        </div>
        

        {#if errorMsg}
          <div class="rounded-lg bg-red-50 p-3 text-sm text-red-600">{errorMsg}</div>
        {/if}

        <div class="flex justify-end gap-2 pt-2">
          <button class="rounded-lg border px-4 py-2" on:click={close} disabled={submitting}>Cancel</button>
          <button class="rounded-lg bg-orange-600 px-4 py-2 text-white disabled:opacity-50" on:click|preventDefault={onSubmit} disabled={submitting}>
            {submitting ? 'Submitting…' : 'Save Changes'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
