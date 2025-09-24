<script lang="ts">
  import { businesses } from "$lib/data/businesses";
  import Button from "$lib/components/Button.svelte";

  // Mock portfolio data - in real app this would come from user's account
  const portfolioHoldings = [
    {
      businessId: "1",
      shares: 22,
      purchasePrice: 42.3,
      purchaseDate: "2024-01-15",
    },
    {
      businessId: "2",
      shares: 8,
      purchasePrice: 75.5,
      purchaseDate: "2024-02-03",
    },
    {
      businessId: "5",
      shares: 15,
      purchasePrice: 54.2,
      purchaseDate: "2024-02-20",
    },
  ];

  $: portfolioWithDetails = portfolioHoldings
    .map((holding) => {
      const business = businesses.find((b) => b.id === holding.businessId);
      if (!business) return null;

      const currentValue = holding.shares * business.pricePerShare;
      const investedAmount = holding.shares * holding.purchasePrice;
      const gainLoss = currentValue - investedAmount;
      const gainLossPercent = (gainLoss / investedAmount) * 100;

      return {
        ...holding,
        business,
        currentValue,
        investedAmount,
        gainLoss,
        gainLossPercent,
      };
    })
    .filter(Boolean);

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

  function formatCurrency(amount) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 2,
    }).format(amount);
  }

  function formatDate(dateString) {
    return new Date(dateString).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }
</script>

<svelte:head>
  <title>Portfolio - Gildi</title>
</svelte:head>

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
        {totalGainLossPercent >= 0 ? "+" : ""}{totalGainLossPercent.toFixed(2)}%
      </div>
    </div>
  </div>

  {#if portfolioWithDetails.length === 0}
    <!-- Empty State -->
    <div class="bg-white rounded-xl border border-gray-200 p-12 text-center">
      <div class="flex justify-center mb-6">
        <img
          src="/Icon lite.png"
          alt="Gildi Icon"
          class="h-16 w-16 opacity-50"
        />
      </div>
      <h3 class="text-xl font-semibold text-gray-900 mb-2">
        No investments yet
      </h3>
      <p class="text-gray-600 mb-6">
        Start building your portfolio by investing in tokenized business shares
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
                >Avg. Price</th
              >
              <th
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >Current Price</th
              >
              <th
                class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                >Market Value</th
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
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {holding.shares}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatCurrency(holding.purchasePrice)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatCurrency(holding.business.pricePerShare)}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {formatCurrency(holding.currentValue)}
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
                        ? "+"
                        : ""}{holding.gainLossPercent.toFixed(2)}%)
                    </span>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm">
                  <div class="flex space-x-2">
                    <Button
                      variant="outline"
                      size="sm"
                      href="/business/{holding.business.id}">View</Button
                    >
                    <Button variant="primary" size="sm">Trade</Button>
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
                    ? "+"
                    : ""}{holding.gainLossPercent.toFixed(2)}%
                </div>
              </div>
            </div>
            <div class="flex justify-between text-sm text-gray-600 mb-3">
              <span>Avg. Price: {formatCurrency(holding.purchasePrice)}</span>
              <span
                >Current: {formatCurrency(holding.business.pricePerShare)}</span
              >
            </div>
            <div class="flex space-x-2">
              <Button
                variant="outline"
                size="sm"
                href="/business/{holding.business.id}"
                class="flex-1">View</Button
              >
              <Button variant="primary" size="sm" class="flex-1">Trade</Button>
            </div>
          </div>
        {/each}
      </div>
    </div>
  {/if}
</div>
