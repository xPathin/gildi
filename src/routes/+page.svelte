<script lang="ts">
  import { businesses } from '$lib/data/businesses';
  import BusinessCard from '$lib/components/BusinessCard.svelte';
  import Button from '$lib/components/Button.svelte';
  import { onMount } from 'svelte';
  
  let searchQuery = '';
  let selectedIndustry = '';
  let selectedRiskLevel = '';
  let currentSlide = 0;
  let tickerOffset = 0;
  
  $: filteredBusinesses = businesses.filter(business => {
    const matchesSearch = business.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         business.industry.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesIndustry = !selectedIndustry || business.industry === selectedIndustry;
    const matchesRisk = !selectedRiskLevel || business.riskLevel === selectedRiskLevel;
    
    return matchesSearch && matchesIndustry && matchesRisk;
  });
  
  $: industries = [...new Set(businesses.map(b => b.industry))];
  $: riskLevels = [...new Set(businesses.map(b => b.riskLevel))];
  
  // Featured shares (top 6 by market cap)
  $: featuredShares = [...businesses]
    .sort((a, b) => b.marketCap - a.marketCap)
    .slice(0, 6);
  
  // Top gainers and losers for ticker
  $: topGainers = [...businesses]
    .sort((a, b) => parseFloat(b.keyMetrics.revenueGrowth) - parseFloat(a.keyMetrics.revenueGrowth))
    .slice(0, 5)
    .map(b => ({ ...b, change: `+${b.keyMetrics.revenueGrowth}`, isGainer: true }));
    
  $: topLosers = [...businesses]
    .sort((a, b) => parseFloat(a.keyMetrics.revenueGrowth) - parseFloat(b.keyMetrics.revenueGrowth))
    .slice(0, 3)
    .map(b => ({ ...b, change: b.keyMetrics.revenueGrowth, isGainer: false }));
    
  $: tickerItems = [...topGainers, ...topLosers];
  
  function formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount);
  }
  
  function nextSlide() {
    currentSlide = (currentSlide + 1) % Math.ceil(featuredShares.length / 3);
  }
  
  function prevSlide() {
    currentSlide = currentSlide === 0 ? Math.ceil(featuredShares.length / 3) - 1 : currentSlide - 1;
  }
  
  function goToSlide(index) {
    currentSlide = index;
  }
  
  // Auto-advance slider
  onMount(() => {
    const slideInterval = setInterval(nextSlide, 5000);
    
    // Ticker animation
    const tickerInterval = setInterval(() => {
      tickerOffset -= 1;
      if (tickerOffset <= -100) {
        tickerOffset = 0;
      }
    }, 50);
    
    return () => {
      clearInterval(slideInterval);
      clearInterval(tickerInterval);
    };
  });
</script>

<svelte:head>
  <title>Gildi - Business Share Tokenization Marketplace</title>
  <meta name="description" content="Invest in tokenized shares of growing businesses. Diversify your portfolio with fractional ownership opportunities." />
</svelte:head>

<div class="min-h-screen bg-gray-50">
  <!-- Hero Section with Featured Shares -->
  <div class="bg-gradient-to-br from-orange-50 to-orange-100 py-12">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Featured Shares Slider -->
      <div class="mb-8">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Featured Opportunities</h2>
          <div class="flex items-center space-x-2">
            <button 
              on:click={prevSlide}
              class="p-2 rounded-full bg-white shadow-md hover:shadow-lg transition-shadow"
            >
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <button 
              on:click={nextSlide}
              class="p-2 rounded-full bg-white shadow-md hover:shadow-lg transition-shadow"
            >
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
        </div>
        
        <!-- Slider Container -->
        <div class="relative overflow-hidden">
          <div 
            class="flex transition-transform duration-500 ease-in-out"
            style="transform: translateX(-{currentSlide * 100}%)"
          >
            {#each Array(Math.ceil(featuredShares.length / 3)) as _, slideIndex}
              <div class="w-full flex-shrink-0">
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {#each featuredShares.slice(slideIndex * 3, slideIndex * 3 + 3) as business}
                    <div class="transform hover:scale-105 transition-transform duration-200">
                      <!-- Simplified Featured Card -->
                      <div class="bg-white rounded-xl border border-gray-200 shadow-sm hover:shadow-md transition-shadow p-6">
                        <div class="flex items-start justify-between mb-4">
                          <div class="flex items-center space-x-3">
                            <div class="w-12 h-12 bg-orange-50 rounded-xl flex items-center justify-center text-2xl">
                              {business.logo}
                            </div>
                            <div>
                              <h3 class="font-semibold text-gray-900">{business.name}</h3>
                              <p class="text-sm text-gray-500">{business.industry}</p>
                            </div>
                          </div>
                          <div class="text-right">
                            <div class="text-lg font-bold text-gray-900">
                              {formatCurrency(business.pricePerShare)}
                            </div>
                            <div class="text-sm text-green-600">
                              +{business.keyMetrics.revenueGrowth}
                            </div>
                          </div>
                        </div>
                        
                        <p class="text-gray-600 text-sm mb-4 line-clamp-2">
                          {business.description.slice(0, 100)}...
                        </p>
                        
                        <div class="flex items-center justify-between">
                          <div class="text-sm text-gray-500">
                            Min: {formatCurrency(business.minimumInvestment)}
                          </div>
                          <Button variant="primary" size="sm" href="/business/{business.id}">
                            Invest Now
                          </Button>
                        </div>
                      </div>
                    </div>
                  {/each}
                </div>
              </div>
            {/each}
          </div>
        </div>
        
        <!-- Slider Dots -->
        <div class="flex justify-center mt-6 space-x-2">
          {#each Array(Math.ceil(featuredShares.length / 3)) as _, index}
            <button
              on:click={() => goToSlide(index)}
              class="w-3 h-3 rounded-full transition-colors duration-200 {currentSlide === index ? 'bg-orange-600' : 'bg-gray-300'}"
            ></button>
          {/each}
        </div>
      </div>
    </div>
  </div>
  
  <!-- Market Ticker -->
  <div class="bg-white border-b border-gray-200 py-3 overflow-hidden">
    <div class="relative">
      <div 
        class="flex space-x-8 animate-scroll"
        style="transform: translateX({tickerOffset}%)"
      >
        {#each [...tickerItems, ...tickerItems] as item}
          <div class="flex items-center space-x-3 whitespace-nowrap">
            <div class="w-8 h-8 bg-orange-50 rounded-lg flex items-center justify-center text-sm">
              {item.logo}
            </div>
            <div class="flex items-center space-x-2">
              <span class="font-semibold text-gray-900">{item.name}</span>
              <span class="text-sm text-gray-500">({item.industry.slice(0, 4).toUpperCase()})</span>
              <span class="font-medium {item.isGainer ? 'text-green-600' : 'text-red-600'}">
                {item.change}
              </span>
              <span class="text-sm text-gray-600">
                {formatCurrency(item.pricePerShare)}
              </span>
            </div>
          </div>
        {/each}
      </div>
    </div>
  </div>
  
  <!-- Marketplace Section -->
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
    <!-- Search and Filters -->
    <div class="mb-8">
      <div class="flex flex-col lg:flex-row gap-4 items-center justify-between">
        <div class="flex-1 max-w-md">
          <input
            type="text"
            placeholder="Search companies..."
            bind:value={searchQuery}
            class="input"
          />
        </div>
        <div class="flex gap-4">
          <select bind:value={selectedIndustry} class="input">
            <option value="">All Industries</option>
            {#each industries as industry}
              <option value={industry}>{industry}</option>
            {/each}
          </select>
          <select bind:value={selectedRiskLevel} class="input">
            <option value="">All Risk Levels</option>
            {#each riskLevels as risk}
              <option value={risk}>{risk} Risk</option>
            {/each}
          </select>
        </div>
      </div>
    </div>
    
    <!-- Results Header -->
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-900">
        All Investment Opportunities
        <span class="text-lg font-normal text-gray-500">({filteredBusinesses.length} companies)</span>
      </h2>
    </div>
    
    <!-- Business Grid -->
    {#if filteredBusinesses.length > 0}
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {#each filteredBusinesses as business}
          <BusinessCard {business} />
        {/each}
      </div>
    {:else}
      <div class="text-center py-12">
        <div class="text-gray-400 text-6xl mb-4">🔍</div>
        <h3 class="text-xl font-semibold text-gray-900 mb-2">No companies found</h3>
        <p class="text-gray-600 mb-6">Try adjusting your search criteria or filters</p>
        <Button variant="outline" on:click={() => {searchQuery = ''; selectedIndustry = ''; selectedRiskLevel = '';}}>
          Clear Filters
        </Button>
      </div>
    {/if}
  </div>
</div>

<style>
  @keyframes scroll {
    0% {
      transform: translateX(100%);
    }
    100% {
      transform: translateX(-100%);
    }
  }
  
  .animate-scroll {
    animation: scroll 60s linear infinite;
  }
  
  .line-clamp-2 {
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
</style>