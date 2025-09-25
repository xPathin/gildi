import js from '@eslint/js';
import tseslint from '@typescript-eslint/eslint-plugin';
import tsParser from '@typescript-eslint/parser';
import sveltePlugin from 'eslint-plugin-svelte';
import svelteParser from 'svelte-eslint-parser';
import prettier from 'eslint-config-prettier';

export default [
  {
    ignores: [
      '.svelte-kit/**',
      '.vercel/**',
      'build/**',
      'dist/**',
      'node_modules/**',
      'backend/**',
      '*.config.js',
      'pnpm-lock.yaml',
      'package-lock.json',
    ],
  },
  // JavaScript files
  {
    files: ['src/**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
    },
    rules: {
      ...js.configs.recommended.rules,
    },
  },
  // TypeScript files
  {
    files: ['src/**/*.ts'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      parser: tsParser,
    },
    plugins: {
      '@typescript-eslint': tseslint,
    },
    rules: {
      ...js.configs.recommended.rules,
      '@typescript-eslint/no-unused-vars': 'warn',
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },
  // Svelte files
  {
    files: ['src/**/*.svelte'],
    languageOptions: {
      parser: svelteParser,
      parserOptions: {
        parser: tsParser,
      },
    },
    plugins: {
      svelte: sveltePlugin,
    },
    rules: {
      // Basic JS rules that work in Svelte
      'no-unused-vars': 'off', // Handled by TypeScript or Svelte compiler
      'no-undef': 'off', // Svelte has its own scope
    },
  },
  // Prettier config (must be last to override other formatting rules)
  prettier,
];
