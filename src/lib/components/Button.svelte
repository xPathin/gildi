<script lang="ts">
  export let variant = 'primary';
  export let size = 'md';
  export let href = undefined;
  export let disabled = false;
  export let type = 'button';

  let className = '';
  export { className as class };

  $: baseClasses =
    'inline-flex items-center justify-center font-medium rounded-lg transition-colors duration-200 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

  $: variantClasses = {
    primary:
      'bg-orange-600 hover:bg-orange-700 text-white focus:ring-orange-500',
    secondary:
      'bg-gray-100 hover:bg-gray-200 text-gray-900 focus:ring-gray-500',
    outline:
      'border border-gray-300 hover:bg-gray-50 text-gray-700 focus:ring-gray-500',
  };

  $: sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  $: classes = `${baseClasses} ${variantClasses[variant]} ${sizeClasses[size]} ${className}`;
</script>

{#if href}
  <a {href} class={classes} class:pointer-events-none={disabled}>
    <slot />
  </a>
{:else}
  <button {type} {disabled} class={classes} on:click>
    <slot />
  </button>
{/if}
