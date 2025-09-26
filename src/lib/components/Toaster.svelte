<script lang="ts">
  import { toasts } from '$lib/stores/toast';
  import { fly } from 'svelte/transition';
</script>

<div class="fixed inset-0 pointer-events-none z-[1000]">
  <div class="absolute top-4 right-4 space-y-3 w-full max-w-sm ml-auto mr-4">
    {#each $toasts as t (t.id)}
      <div
        in:fly={{ y: -10, duration: 150 }}
        out:fly={{ y: -10, duration: 150 }}
        class="pointer-events-auto rounded-lg border p-3 shadow bg-white flex items-start gap-3 justify-between"
        class:border-green-200={t.type === 'success'}
        class:border-red-200={t.type === 'error'}
        class:border-gray-200={t.type === 'info'}
      >
        <div class="mt-0.5 text-sm"
          class:text-green-700={t.type === 'success'}
          class:text-red-700={t.type === 'error'}
          class:text-gray-700={t.type === 'info'}
        >
          {t.message}
        </div>
        {#if t.linkUrl}
          <a
            href={t.linkUrl}
            target="_blank"
            rel="noopener noreferrer"
            class="ml-3 text-sm text-orange-700 hover:text-orange-800 underline"
          >{t.linkLabel || 'Open'}</a>
        {/if}
      </div>
    {/each}
  </div>
</div>
