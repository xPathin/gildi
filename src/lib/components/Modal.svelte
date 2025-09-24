<script lang="ts">
  export let show = false;
  export let title = "";

  function handleBackdropClick(event) {
    if (event.target === event.currentTarget) {
      show = false;
    }
  }

  function handleKeydown(event) {
    if (event.key === "Escape") {
      show = false;
    }
  }
</script>

{#if show}
  <!-- Backdrop -->
  <div
    class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
    on:click={handleBackdropClick}
    on:keydown={handleKeydown}
    role="dialog"
    aria-modal="true"
    tabindex="-1"
  >
    <!-- Modal -->
    <div
      class="bg-white rounded-xl shadow-xl max-w-md w-full max-h-[90vh] overflow-y-auto"
    >
      <!-- Header -->
      <div
        class="flex items-center justify-between p-6 border-b border-gray-200"
      >
        <h2 class="text-xl font-semibold text-gray-900">{title}</h2>
        <button
          on:click={() => (show = false)}
          class="text-gray-400 hover:text-gray-600 focus:outline-none focus:text-gray-600"
        >
          <svg
            class="w-6 h-6"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      <!-- Content -->
      <div class="p-6">
        <slot />
      </div>
    </div>
  </div>
{/if}
