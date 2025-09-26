<script lang="ts">
  import '../app.css';
  import Navigation from '$lib/components/Navigation.svelte';
  import Toaster from '$lib/components/Toaster.svelte';
  import { onMount } from 'svelte';
  import { initAppKit } from '$lib/wagmi/config';

  onMount(() => {
    initAppKit();
  });
</script>

<div class="min-h-screen bg-gray-50">
  <Navigation />
  <main>
    <slot />
  </main>
  <Toaster />
</div>
