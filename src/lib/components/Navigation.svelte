<script>
  import { page } from "$app/stores";
  import Button from "./Button.svelte";

  $: currentPath = $page.url.pathname;
</script>

<nav class="bg-white border-b border-gray-200 sticky top-0 z-40">
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="flex justify-between items-center h-16">
      <!-- Logo -->
      <div class="flex items-center">
        <a href="/" class="flex items-center space-x-3">
          <img src="/Logo Black.png" alt="Gildi" class="h-8 w-auto" />
        </a>
      </div>

      <!-- Navigation Links -->
      <div class="hidden md:flex items-center space-x-8">
        <a
          href="/"
          class="text-gray-700 hover:text-orange-600 px-3 py-2 text-sm font-medium transition-colors"
          class:text-orange-600={currentPath === "/"}
          class:font-semibold={currentPath === "/"}
        >
          Marketplace
        </a>
        <a
          href="/portfolio"
          class="text-gray-700 hover:text-orange-600 px-3 py-2 text-sm font-medium transition-colors"
          class:text-orange-600={currentPath === "/portfolio"}
          class:font-semibold={currentPath === "/portfolio"}
        >
          Portfolio
        </a>
        <a
          href="/onboarding"
          class="text-gray-700 hover:text-orange-600 px-3 py-2 text-sm font-medium transition-colors"
          class:text-orange-600={currentPath === "/onboarding"}
          class:font-semibold={currentPath === "/onboarding"}
        >
          Get Started
        </a>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center space-x-4">
        <Button variant="outline" size="sm">Sign In</Button>
        <Button variant="primary" size="sm" href="/onboarding"
          >Start Investing</Button
        >
      </div>

      <!-- Mobile menu button -->
      <div class="md:hidden">
        <button
          class="text-gray-700 hover:text-orange-600 focus:outline-none focus:text-orange-600"
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
              d="M4 6h16M4 12h16M4 18h16"
            />
          </svg>
        </button>
      </div>
    </div>
  </div>
</nav>
