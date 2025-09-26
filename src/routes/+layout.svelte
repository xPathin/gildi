<script lang="ts">
  import '../app.css';
  import Navigation from '$lib/components/Navigation.svelte';
  import Toaster from '$lib/components/Toaster.svelte';
</script>

<div class="min-h-screen bg-gray-50">
  <Navigation />
  <main>
    <slot />
  </main>
  <Toaster />
</div>
