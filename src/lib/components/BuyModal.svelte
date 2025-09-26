<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { wallet } from '$lib/wagmi/walletStore';
  import type { WalletState } from '$lib/wagmi/walletStore';
  import type { Address } from 'viem';
  import { toast } from '$lib/stores/toast';
  import { config } from '$lib/wagmi/config';
  import { switchChain } from '@wagmi/core';
  import { optimismSepolia } from 'viem/chains';
  import {
    getAllowedPurchaseTokens,
    estimatePurchase as estimatePurchaseFn,
    canBuy as canBuyFn,
    getErc20Meta,
    getAllowance,
    getErc20Balance,
    approve,
    purchase as purchaseFn,
  } from '$lib/contracts/purchase';
  import { ADDRESSES } from '$lib/contracts/addresses';

  export let open = false;
  export let releaseId: bigint;
  export let prefillQuantity: bigint | undefined;

  const dispatch = createEventDispatcher();

  let walletState: WalletState | undefined;
  $: walletState = $wallet as WalletState;
  $: account = walletState?.address as Address | undefined;
  $: chainId = walletState?.chainId as number | undefined;
  $: isOnOptimism = chainId === optimismSepolia.id;

  type TokenMeta = { symbol: string; name: string; decimals: number };
  let allowedTokens: Address[] = [];
  let tokenMeta: Record<string, TokenMeta> = {};
  let selectedToken: Address | undefined;
  let balances: Record<string, bigint> = {};

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
  let initLoading = false;
  let initError: string | undefined;
  let tokensReady = false;
  let balancesLoading = false;
  let hydratedOnce = false;

  // Slippage (basis points)
  let slippageBps = 50; // default 0.50%
  let customSlippageStr = '';
  function setSlippage(bps: number) {
    slippageBps = bps;
    customSlippageStr = '';
  }
  function onCustomSlippageInput() {
    const n = Number(customSlippageStr);
    if (!isFinite(n) || n < 0) return;
    slippageBps = Math.floor(n);
  }

  // Derived: max spend with slippage buffer and balance sufficiency
  let maxSpend: bigint | undefined;
  $: maxSpend =
    sourceNeeded != null
      ? (sourceNeeded * (10000n + BigInt(slippageBps))) / 10000n
      : undefined;
  $: hasEnoughBalance =
    account && selectedToken && maxSpend != null
      ? (balances[selectedToken] ?? 0n) >= maxSpend
      : undefined;

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

  async function loadTokensOnce() {
    if (tokensReady) return;
    initError = undefined;
    initLoading = true;
    try {
      allowedTokens = await getAllowedPurchaseTokens();
      tokenMeta = {};
      await Promise.all(
        allowedTokens.map(async (addr) => {
          const meta = await getErc20Meta(addr);
          tokenMeta[addr] = meta;
        })
      );
      if (!selectedToken) {
        const pref = [
          ADDRESSES.tokens?.mockUSDC,
          ADDRESSES.tokens?.mockWETH,
          // ADDRESSES.tokens?.mockRUST,
        ].filter(Boolean) as Address[];
        selectedToken =
          pref.find((p) => allowedTokens.includes(p)) ?? allowedTokens[0];
      }
      tokensReady = true;
    } catch (e) {
      console.error('Buy tokens load error', e);
      initError = e instanceof Error ? e.message : 'Failed to load tokens';
    } finally {
      initLoading = false;
    }
  }

  async function refreshAccountData() {
    // Do not clear balances to avoid flashing 0
    if (account && allowedTokens.length) {
      balancesLoading = true;
      try {
        const pairs = await Promise.all(
          allowedTokens.map(async (addr) => {
            const bal = await getErc20Balance(addr, account!);
            return [addr, bal] as const;
          })
        );
        for (const [addr, bal] of pairs) balances[addr] = bal;
      } catch (e) {
        console.error('Buy balances load error', e);
      } finally {
        balancesLoading = false;
      }
    }
    // CanBuy and estimate
    if (account) {
      try {
        const res = await canBuyFn(releaseId, account);
        canBuyAllowed = res.buyAllowed;
        maxBuyAmount = res.maxBuyAmount;
      } catch (e) {
        canBuyAllowed = undefined;
        maxBuyAmount = undefined;
      }
      await doEstimate();
    } else {
      canBuyAllowed = undefined;
      maxBuyAmount = undefined;
    }
  }

  // open lifecycle handled below in onOpen()

  async function doEstimate() {
    estError = undefined;
    sourceNeeded = undefined;
    totalPriceUsd = undefined;
    if (!selectedToken) return;
    if (!account) {
      // Can't estimate without buyer context for whitelist etc.
      return;
    }
    const qty = parseQuantity();
    if (!qty) return;
    if (maxBuyAmount !== undefined && qty > maxBuyAmount) {
      estError = `Exceeds max allowed for this operation (${String(maxBuyAmount)} shares)`;
      return;
    }
    estLoading = true;
    try {
      const res = await estimatePurchaseFn(
        releaseId,
        qty,
        account,
        selectedToken
      );
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

  // Manage open lifecycle without repeated full rehydrates
  let wasOpen = false;
  let lastAccount: Address | undefined;
  async function onOpen() {
    await loadTokensOnce();
    if (prefillQuantity && prefillQuantity > 0n) {
      quantityStr = String(prefillQuantity);
    }
    await refreshAccountData();
  }
  $: if (open && !wasOpen) {
    wasOpen = true;
    onOpen();
  }
  $: if (!open && wasOpen) {
    wasOpen = false;
  }
  $: if (open && account !== lastAccount) {
    lastAccount = account;
    // Only refresh account-dependent data; do not reload tokens/meta
    refreshAccountData();
  }

  function close() {
    open = false;
    dispatch('close');
  }

  async function onPurchase() {
    if (!selectedToken) return;
    if (!account) {
      toast.info('Connect your wallet to purchase');
      return;
    }
    if (!isOnOptimism) {
      try {
        await switchChain(config, { chainId: optimismSepolia.id });
      } catch (e) {
        toast.error('Please switch to Optimism Sepolia');
        return;
      }
    }
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
      toast.error(
        `Exceeds max allowed per operation (${String(maxBuyAmount)} shares)`
      );
      return;
    }
    if (sourceNeeded === undefined) {
      toast.error('Unable to estimate cost. Please try again later.');
      return;
    }

    submitting = true;
    try {
      // Check balance sufficiency with slippage buffer
      const buffer = (sourceNeeded * (10000n + BigInt(slippageBps))) / 10000n;
      if ((balances[selectedToken] ?? 0n) < buffer) {
        toast.error('Insufficient balance for selected token');
        return;
      }
      // Allowance
      const allowance = await getAllowance(
        selectedToken,
        account,
        ADDRESSES.aggregator as Address
      );
      if (allowance < buffer) {
        toast.info('Approving token for purchase…');
        await approve(selectedToken, ADDRESSES.aggregator as Address, buffer);
        toast.success('Approval confirmed');
      }

      // Slippage buffer from user selection
      toast.info('Submitting purchase…');
      const receipt = await purchaseFn(releaseId, qty, selectedToken, buffer);
      const url = `https://testnet-explorer.optimism.io/tx/${receipt.transactionHash}`;
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
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
  >
    <div class="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">Buy Shares</h3>
        <button class="text-gray-500 hover:text-gray-700" on:click={close}
          >✕</button
        >
      </div>

      <div class="space-y-4">
        {#if account && !isOnOptimism}
          <div
            class="rounded-lg bg-yellow-50 p-3 text-sm text-yellow-800 flex items-center justify-between"
          >
            <span>Wrong network. Please switch to Optimism Sepolia.</span>
            <button
              class="rounded bg-yellow-600 text-white px-3 py-1"
              on:click={() =>
                switchChain(config, { chainId: optimismSepolia.id })}
              >Switch</button
            >
          </div>
        {/if}
        {#if !account}
          <div class="rounded-lg bg-blue-50 p-3 text-sm text-blue-800">
            Connect your wallet to estimate and purchase.
          </div>
        {/if}
        <div>
          <label for="paymentToken" class="block text-sm text-gray-600 mb-1"
            >Payment Token</label
          >
          {#if !tokensReady || initLoading}
            <div class="h-10 w-full rounded-lg bg-gray-100 animate-pulse"></div>
          {:else}
            <select
              id="paymentToken"
              class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring"
              bind:value={selectedToken}
              on:change={() => doEstimate()}
            >
              {#each allowedTokens as t (t)}
                <option value={t}>{tokenMeta[t]?.symbol}</option>
              {/each}
            </select>
          {/if}
          {#if selectedToken && account}
            <p class="mt-1 text-xs text-gray-500">
              Balance:
              {#if balances[selectedToken] != null}
                {formatAmount(
                  balances[selectedToken]!,
                  tokenMeta[selectedToken!]?.decimals || 18
                )}
                {tokenMeta[selectedToken!]?.symbol || ''}
              {:else}
                —
              {/if}
            </p>
          {/if}
        </div>

        <div>
          <label for="buyQuantity" class="block text-sm text-gray-600 mb-1"
            >Quantity (shares)</label
          >
          <input
            id="buyQuantity"
            type="number"
            min="1"
            step="1"
            bind:value={quantityStr}
            class="w-full rounded-lg border px-3 py-2 focus:outline-none focus:ring"
            placeholder="0"
            on:input={() => doEstimate()}
          />
          {#if maxBuyAmount !== undefined}
            <p class="mt-1 text-xs text-gray-500">
              Available for you: {String(maxBuyAmount)} shares
            </p>
          {/if}
        </div>

        <div class="bg-gray-50 p-4 rounded-lg text-sm">
          <div class="flex justify-between mb-1">
            <span>Estimated Cost:</span>
            <span>
              {#if estLoading}
                Estimating…
              {:else if sourceNeeded != null && selectedToken}
                {formatAmount(
                  sourceNeeded,
                  tokenMeta[selectedToken!]?.decimals || 18
                )}
                {tokenMeta[selectedToken!]?.symbol || ''}
              {:else}
                —
              {/if}
            </span>
          </div>
          <div class="flex justify-between">
            <span>Approx. USD:</span>
            <span>{formatUsdCents(totalPriceUsd)}</span>
          </div>
          <div class="flex justify-between mt-1">
            <span>Max spend (with slippage):</span>
            <span>
              {#if maxSpend != null && selectedToken}
                {formatAmount(
                  maxSpend,
                  tokenMeta[selectedToken!]?.decimals || 18
                )}
                {tokenMeta[selectedToken!]?.symbol || ''}
              {:else}
                —
              {/if}
            </span>
          </div>
          {#if estError}
            <div class="mt-2 text-red-600">{estError}</div>
          {/if}
          {#if account && selectedToken && maxSpend != null && (balances[selectedToken] ?? 0n) < maxSpend}
            <div class="mt-2 text-red-600">Insufficient balance</div>
          {/if}
        </div>

        <div>
          <div class="block text-sm text-gray-600 mb-1">Slippage</div>
          <div class="flex items-center gap-2">
            <button
              type="button"
              class="px-3 py-1 rounded border"
              class:bg-orange-600={slippageBps === 10}
              class:text-white={slippageBps === 10}
              on:click={() => setSlippage(10)}>0.1%</button
            >
            <button
              type="button"
              class="px-3 py-1 rounded border"
              class:bg-orange-600={slippageBps === 50}
              class:text-white={slippageBps === 50}
              on:click={() => setSlippage(50)}>0.5%</button
            >
            <button
              type="button"
              class="px-3 py-1 rounded border"
              class:bg-orange-600={slippageBps === 100}
              class:text-white={slippageBps === 100}
              on:click={() => setSlippage(100)}>1%</button
            >
            <div class="flex items-center gap-2 ml-2">
              <input
                type="number"
                min="0"
                step="1"
                class="w-20 rounded-lg border px-2 py-1"
                placeholder="bps"
                bind:value={customSlippageStr}
                on:input={onCustomSlippageInput}
              />
              <span class="text-sm text-gray-500">bps</span>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-2 pt-2">
          <button
            class="rounded-lg border px-4 py-2"
            on:click={close}
            disabled={submitting}>Cancel</button
          >
          <button
            class="rounded-lg bg-orange-600 px-4 py-2 text-white disabled:opacity-50"
            on:click|preventDefault={onPurchase}
            disabled={submitting ||
              !selectedToken ||
              !account ||
              (account &&
                selectedToken &&
                maxSpend != null &&
                (balances[selectedToken] ?? 0n) < maxSpend)}
          >
            {submitting ? 'Purchasing…' : 'Purchase'}
          </button>
        </div>
      </div>
    </div>
  </div>
{/if}
