<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { wallet } from '$lib/wagmi/walletStore';
  import type { WalletState } from '$lib/wagmi/walletStore';
  import type { Address } from 'viem';
  import { toast } from '$lib/stores/toast';
  import {
    getAllowedPurchaseTokens,
    estimatePurchase as estimatePurchaseFn,
    canBuy as canBuyFn,
    getErc20Meta,
    getAllowance,
    approve,
    purchase as purchaseFn,
  } from '$lib/contracts/purchase';
  import { ADDRESSES } from '$lib/contracts/addresses';

  export let open = false;
  export let releaseId: bigint;

  const dispatch = createEventDispatcher();

  let walletState: WalletState | undefined;
  $: walletState = $wallet as WalletState;
  $: account = walletState?.address as Address | undefined;

  type TokenMeta = { symbol: string; name: string; decimals: number };
  let allowedTokens: Address[] = [];
  let tokenMeta: Record<string, TokenMeta> = {};
  let selectedToken: Address | undefined;

  // Buying state
  let quantityStr = '';
  let estLoading = false;
  let estError: string | undefined;
  let sourceNeeded: bigint | undefined;
  let totalPriceUsd: bigint | undefined;
  let releaseCurrency: Address | undefined;
  let canBuyAllowed: boolean | undefined;
  let maxBuyAmount: bigint | undefined;
  let submitting = false;

  function formatAmount(raw: bigint | undefined, decimals = 18) {
    if (raw === undefined) return '—';
    const s = Number(raw) / 10 ** decimals;
    return s.toLocaleString(undefined, { maximumFractionDigits: 6 });
  }
  function formatUsdCents(cents: bigint | undefined) {
    if (cents === undefined) return '—';
    return `$${(Number(cents) / 100).toFixed(2)}`;
    }

  function parseQuantity(): bigint | undefined {
    const n = Number(quantityStr);
    if (!isFinite(n) || n <= 0) return undefined;
    return BigInt(Math.floor(n));
  }

  async function hydrate() {
    if (!open || !account) return;
    try {
      // Allowed tokens
      allowedTokens = await getAllowedPurchaseTokens();
      // Fetch metadata
      tokenMeta = {};
      await Promise.all(
        allowedTokens.map(async (addr) => {
          const meta = await getErc20Meta(addr);
          tokenMeta[addr] = meta;
        })
      );
      // Default selection
      if (!selectedToken) {
        const pref = [ADDRESSES.tokens?.mockUSDC, ADDRESSES.tokens?.mockWETH, ADDRESSES.tokens?.mockRUST].filter(
          Boolean
        ) as Address[];
        selectedToken = pref.find((p) => allowedTokens.includes(p)) ?? allowedTokens[0];
      }
      // CanBuy
      const res = await canBuyFn(releaseId, account);
      canBuyAllowed = res.buyAllowed;
      maxBuyAmount = res.maxBuyAmount;
      // Initial estimate if quantity present
      await doEstimate();
    } catch (e) {
      console.error('Buy hydrate error', e);
      estError = e instanceof Error ? e.message : 'Failed to load purchase data';
    }
  }

  $: if (open) {
    // refresh when opening
    hydrate();
  }

  async function doEstimate() {
    estError = undefined;
    sourceNeeded = undefined;
    totalPriceUsd = undefined;
    if (!account || !selectedToken) return;
    const qty = parseQuantity();
    if (!qty) return;
    if (maxBuyAmount !== undefined && qty > maxBuyAmount) {
      estError = `Exceeds max allowed per operation (${String(maxBuyAmount)} shares)`;
      return;
    }
    estLoading = true;
    try {
      const res = await estimatePurchaseFn(releaseId, qty, account, selectedToken);
      sourceNeeded = res.sourceNeeded;
      totalPriceUsd = res.totalPriceUsd;
      releaseCurrency = res.releaseCurrency;
    } catch (e) {
      console.error('estimatePurchase error', e);
      estError = 'Unable to estimate. Please try again.';
    } finally {
      estLoading = false;
    }
  }

  $: if (open) {
    // re-estimate when inputs change
    void doEstimate();
  }

  function close() {
    open = false;
    dispatch('close');
  }

  async function onPurchase() {
    if (!account || !selectedToken) return;
    const qty = parseQuantity();
    if (!qty) {
      toast.error('Enter a valid quantity');
      return;
    }
    if (canBuyAllowed === false) {
      toast.error('You are not allowed to buy this release right now');
      return;
    }
    if (maxBuyAmount !== undefined && qty > maxBuyAmount) {
      toast.error(`Exceeds max allowed per operation (${String(maxBuyAmount)} shares)`);
      return;
    }
    if (sourceNeeded === undefined) {
      toast.error('Unable to estimate cost. Please try again later.');
      return;
    }

    submitting = true;
    try {
      // Allowance
      const allowance = await getAllowance(selectedToken, account, ADDRESSES.aggregator as Address);
      if (allowance < sourceNeeded) {
        toast.info('Approving token for purchase…');
        await approve(selectedToken, ADDRESSES.aggregator as Address, sourceNeeded);
        toast.success('Approval confirmed');
      }

      // Add small buffer for slippage (1%)
      const buffer = (sourceNeeded * 101n) / 100n;
      toast.info('Submitting purchase…');
      const receipt = await purchaseFn(releaseId, qty, selectedToken, buffer);
      const url = `https://sepolia-optimism.etherscan.io/tx/${receipt.transactionHash}`;
      toast.successWithLink('Purchase confirmed', url, 'View tx');
      close();
      dispatch('purchased');
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Purchase failed';
      if (msg.toLowerCase().includes('user rejected')) {
        toast.info('Purchase cancelled');
      } else {
        toast.error(`Purchase failed: ${msg}`);
      }
    } finally {
      submitting = false;
    }
  }
</script>

{#if open}
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
    <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">Buy Shares</h3>
        <button class="text-gray-500 hover:text-gray-700" on:click={close}>✕</button>
      </div>

      <div class="space-y-4">
        <div>
          <label for="paymentToken" class="block text-sm text-gray-600 mb-1">Payment Token</label>
          <select id="paymentToken" class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring" bind:value={selectedToken} on:change={() => doEstimate()}>
            {#each allowedTokens as t (t)}
              <option value={t}>{tokenMeta[t]?.symbol || t}</option>
            {/each}
          </select>
        </div>

        <div>
          <label for="buyQuantity" class="block text-sm text-gray-600 mb-1">Quantity (shares)</label>
          <input id="buyQuantity" type="number" min="1" step="1" bind:value={quantityStr} class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring" placeholder="0" on:input={() => doEstimate()} />
          {#if maxBuyAmount !== undefined}
            <p class="mt-1 text-xs text-gray-500">Max per purchase: {String(maxBuyAmount)} shares</p>
          {/if}
        </div>

        <div class="bg-gray-50 p-4 rounded-lg text-sm">
          <div class="flex justify-between mb-1">
            <span>Estimated Cost:</span>
            <span>
              {#if estLoading}
                Estimating…
              {:else if sourceNeeded != null && selectedToken}
                {formatAmount(sourceNeeded, tokenMeta[selectedToken!]?.decimals || 18)} {tokenMeta[selectedToken!]?.symbol || ''}
              {:else}
                —
              {/if}
            </span>
          </div>
          <div class="flex justify-between">
            <span>Approx. USD:</span>
            <span>{formatUsdCents(totalPriceUsd)}</span>
          </div>
          {#if estError}
            <div class="mt-2 text-red-600">{estError}</div>
          {/if}
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button class="rounded-lg border px-4 py-2" on:click={close} disabled={submitting}>Cancel</button>
          <button class="rounded-lg bg-orange-600 px-4 py-2 text-white disabled:opacity-50" on:click|preventDefault={onPurchase} disabled={submitting || !selectedToken}>
            {submitting ? 'Purchasing…' : 'Purchase'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
