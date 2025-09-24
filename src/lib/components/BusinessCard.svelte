<script lang="ts">
  import Button from "./Button.svelte";

  export let business;

  $: sharesSoldPercentage =
    ((business.totalShares - business.availableShares) / business.totalShares) *
    100;

  function formatCurrency(amount) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  }

  function formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + "M";
    }
    if (num >= 1000) {
      return (num / 1000).toFixed(1) + "K";
    }
    return num.toString();
  }
</script>

<div class="card p-6 hover:shadow-lg transition-all duration-300 group">
  <!-- Header -->
  <div class="flex items-start justify-between mb-4">
    <div class="flex items-center space-x-3">
      <div
        class="w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center text-2xl"
      >
        {business.logo}
      </div>
      <div>
        <h3
          class="font-semibold text-gray-900 group-hover:text-primary-600 transition-colors"
        >
          {business.name}
        </h3>
        <p class="text-sm text-gray-500">{business.industry}</p>
      </div>
    </div>
    <div class="text-right">
      <div class="text-lg font-bold text-gray-900">
        ${business.pricePerShare}
      </div>
      <div class="text-xs text-gray-500">per share</div>
    </div>
  </div>

  <!-- Description -->
  <p class="text-gray-600 text-sm mb-4 line-clamp-2">
    {business.description}
  </p>

  <!-- Key Metrics -->
  <div class="grid grid-cols-2 gap-4 mb-4">
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">
        Market Cap
      </div>
      <div class="font-semibold text-gray-900">
        {formatCurrency(business.marketCap)}
      </div>
    </div>
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">Revenue</div>
      <div class="font-semibold text-gray-900">
        {formatCurrency(business.yearlyRevenue)}
      </div>
    </div>
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">
        Revenue Growth
      </div>
      <div class="font-semibold text-green-600">
        {business.keyMetrics.revenueGrowth}
      </div>
    </div>
    <div>
      <div class="text-xs text-gray-500 uppercase tracking-wide">
        Risk Level
      </div>
      <div
        class="font-semibold"
        class:text-green-600={business.riskLevel === "Low"}
        class:text-yellow-600={business.riskLevel === "Medium"}
        class:text-red-600={business.riskLevel === "High"}
      >
        {business.riskLevel}
      </div>
    </div>
  </div>

  <!-- Progress Bar -->
  <div class="mb-4">
    <div class="flex justify-between text-xs text-gray-500 mb-1">
      <span>Shares Sold</span>
      <span>{sharesSoldPercentage.toFixed(1)}%</span>
    </div>
    <div class="w-full bg-gray-200 rounded-full h-2">
      <div
        class="bg-primary-600 h-2 rounded-full transition-all duration-300"
        style="width: {sharesSoldPercentage}%"
      />
    </div>
    <div class="flex justify-between text-xs text-gray-500 mt-1">
      <span>{formatNumber(business.availableShares)} available</span>
      <span>Min: {formatCurrency(business.minimumInvestment)}</span>
    </div>
  </div>

  <!-- Actions -->
  <div class="flex space-x-2">
    <Button
      variant="primary"
      size="sm"
      href="/business/{business.id}"
      class="flex-1"
    >
      View Details
    </Button>
    <Button variant="outline" size="sm" class="px-3">
      <svg
        class="w-4 h-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"
        />
      </svg>
    </Button>
  </div>
</div>

<style>
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
</style>
