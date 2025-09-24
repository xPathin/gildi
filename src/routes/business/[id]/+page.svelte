<script lang="ts">
  import { page } from "$app/stores";
  import { businesses } from "$lib/data/businesses";
  import Button from "$lib/components/Button.svelte";
  import Modal from "$lib/components/Modal.svelte";

  let showBuyModal = false;
  let showSellModal = false;
  let investmentAmount = 1000;
  let shareQuantity = 1;

  $: business = businesses.find((b) => b.id === $page.params.id);
  $: sharesSoldPercentage = business
    ? ((business.totalShares - business.availableShares) /
        business.totalShares) *
      100
    : 0;
  $: maxShares = business
    ? Math.floor(investmentAmount / business.pricePerShare)
    : 0;

  function formatCurrency(amount) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
    }).format(amount);
  }

  function formatNumber(num) {
    return new Intl.NumberFormat("en-US").format(num);
  }

  function handleInvestmentChange() {
    if (business) {
      shareQuantity = Math.floor(investmentAmount / business.pricePerShare);
    }
  }

  function handleShareQuantityChange() {
    if (business) {
      investmentAmount = shareQuantity * business.pricePerShare;
    }
  }
</script>

<svelte:head>
  <title>{business?.name || "Business"} - Gildi</title>
</svelte:head>

{#if !business}
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center">
    <h1 class="text-2xl font-bold text-gray-900 mb-4">Business Not Found</h1>
    <p class="text-gray-600 mb-8">
      The business you're looking for doesn't exist.
    </p>
    <Button href="/">Back to Marketplace</Button>
  </div>
{:else}
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Breadcrumb -->
    <nav class="mb-8">
      <ol class="flex items-center space-x-2 text-sm text-gray-500">
        <li><a href="/" class="hover:text-gray-700">Marketplace</a></li>
        <li>/</li>
        <li class="text-gray-900">{business.name}</li>
      </ol>
    </nav>

    <!-- Header -->
    <div class="bg-white rounded-xl border border-gray-200 p-8 mb-8">
      <div class="flex flex-col lg:flex-row lg:items-start lg:justify-between">
        <div class="flex items-start space-x-6 mb-6 lg:mb-0">
          <div
            class="w-20 h-20 bg-orange-50 rounded-xl flex items-center justify-center text-4xl"
          >
            {business.logo}
          </div>
          <div>
            <h1 class="text-3xl font-bold text-gray-900 mb-2">
              {business.name}
            </h1>
            <p class="text-lg text-gray-600 mb-2">{business.industry}</p>
            <div class="flex items-center space-x-4 text-sm text-gray-500">
              <span>📍 {business.location}</span>
              <span>👥 {business.employees} employees</span>
              <span>📅 Founded {business.founded}</span>
            </div>
          </div>
        </div>

        <div class="text-right">
          <div class="text-4xl font-bold text-gray-900 mb-1">
            {formatCurrency(business.pricePerShare)}
          </div>
          <div class="text-gray-500">per share</div>
          <div class="mt-4 space-y-2">
            <Button
              variant="primary"
              size="lg"
              on:click={() => (showBuyModal = true)}
            >
              Buy Shares
            </Button>
            <Button
              variant="outline"
              size="lg"
              on:click={() => (showSellModal = true)}
            >
              Sell Shares
            </Button>
          </div>
        </div>
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <!-- Main Content -->
      <div class="lg:col-span-2 space-y-8">
        <!-- Description -->
        <div class="bg-white rounded-xl border border-gray-200 p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">
            About {business.name}
          </h2>
          <p class="text-gray-600 leading-relaxed">{business.description}</p>
        </div>

        <!-- Images -->
        <div class="bg-white rounded-xl border border-gray-200 p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Company Images</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            {#each business.images as image}
              <img
                src={image}
                alt={business.name}
                class="w-full h-48 object-cover rounded-lg"
              />
            {/each}
          </div>
        </div>

        <!-- Key Metrics -->
        <div class="bg-white rounded-xl border border-gray-200 p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">
            Financial Metrics
          </h2>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Revenue Growth
              </div>
              <div class="text-2xl font-bold text-green-600">
                {business.keyMetrics.revenueGrowth}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Profit Margin
              </div>
              <div class="text-2xl font-bold text-gray-900">
                {business.keyMetrics.profitMargin}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Debt to Equity
              </div>
              <div class="text-2xl font-bold text-gray-900">
                {business.keyMetrics.debtToEquity}
              </div>
            </div>
            <div>
              <div class="text-sm text-gray-500 uppercase tracking-wide mb-1">
                Return on Equity
              </div>
              <div class="text-2xl font-bold text-gray-900">
                {business.keyMetrics.returnOnEquity}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Sidebar -->
      <div class="space-y-6">
        <!-- Investment Summary -->
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">
            Investment Summary
          </h3>
          <div class="space-y-4">
            <div class="flex justify-between">
              <span class="text-gray-600">Market Cap</span>
              <span class="font-semibold"
                >{formatCurrency(business.marketCap)}</span
              >
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Annual Revenue</span>
              <span class="font-semibold"
                >{formatCurrency(business.yearlyRevenue)}</span
              >
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Total Shares</span>
              <span class="font-semibold"
                >{formatNumber(business.totalShares)}</span
              >
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Available Shares</span>
              <span class="font-semibold"
                >{formatNumber(business.availableShares)}</span
              >
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Minimum Investment</span>
              <span class="font-semibold"
                >{formatCurrency(business.minimumInvestment)}</span
              >
            </div>
            <div class="flex justify-between">
              <span class="text-gray-600">Risk Level</span>
              <span
                class="font-semibold"
                class:text-green-600={business.riskLevel === "Low"}
                class:text-yellow-600={business.riskLevel === "Medium"}
                class:text-red-600={business.riskLevel === "High"}
              >
                {business.riskLevel}
              </span>
            </div>
          </div>
        </div>

        <!-- Share Progress -->
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">
            Share Distribution
          </h3>
          <div class="mb-3">
            <div class="flex justify-between text-sm text-gray-600 mb-1">
              <span>Shares Sold</span>
              <span>{sharesSoldPercentage.toFixed(1)}%</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-3">
              <div
                class="bg-orange-600 h-3 rounded-full transition-all duration-300"
                style="width: {sharesSoldPercentage}%"
              />
            </div>
          </div>
          <div class="text-sm text-gray-600">
            {formatNumber(business.totalShares - business.availableShares)} of {formatNumber(
              business.totalShares
            )} shares sold
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Buy Modal -->
  <Modal bind:show={showBuyModal} title="Buy Shares - {business.name}">
    <div class="space-y-6">
      <div>
        <label
          for="investment-amount"
          class="block text-sm font-medium text-gray-700 mb-2"
          >Investment Amount</label
        >
        <input
          id="investment-amount"
          type="number"
          bind:value={investmentAmount}
          on:input={handleInvestmentChange}
          min={business.minimumInvestment}
          class="input"
          placeholder="Enter amount"
        />
        <p class="text-sm text-gray-500 mt-1">
          Minimum: {formatCurrency(business.minimumInvestment)}
        </p>
      </div>

      <div>
        <label
          for="share-quantity"
          class="block text-sm font-medium text-gray-700 mb-2"
          >Number of Shares</label
        >
        <input
          id="share-quantity"
          type="number"
          bind:value={shareQuantity}
          on:input={handleShareQuantityChange}
          min="1"
          max={business.availableShares}
          class="input"
        />
        <p class="text-sm text-gray-500 mt-1">
          Max available: {formatNumber(business.availableShares)}
        </p>
      </div>

      <div class="bg-gray-50 p-4 rounded-lg">
        <div class="flex justify-between mb-2">
          <span>Share Price:</span>
          <span>{formatCurrency(business.pricePerShare)}</span>
        </div>
        <div class="flex justify-between mb-2">
          <span>Quantity:</span>
          <span>{shareQuantity}</span>
        </div>
        <div class="flex justify-between font-semibold text-lg border-t pt-2">
          <span>Total:</span>
          <span>{formatCurrency(shareQuantity * business.pricePerShare)}</span>
        </div>
      </div>

      <div class="flex space-x-3">
        <Button variant="primary" class="flex-1">Pay with Card</Button>
        <Button variant="outline" class="flex-1">Pay with Crypto</Button>
      </div>
    </div>
  </Modal>

  <!-- Sell Modal -->
  <Modal bind:show={showSellModal} title="Sell Shares - {business.name}">
    <div class="space-y-6">
      <p class="text-gray-600">
        You don't own any shares of {business.name} yet.
      </p>
      <Button
        variant="primary"
        on:click={() => {
          showSellModal = false;
          showBuyModal = true;
        }}
      >
        Buy Shares First
      </Button>
    </div>
  </Modal>
{/if}
