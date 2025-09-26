import { writable } from 'svelte/store';

export type ToastType = 'success' | 'error' | 'info';

export interface Toast {
  id: number;
  type: ToastType;
  message: string;
  timeout: number; // ms
  linkUrl?: string;
  linkLabel?: string;
}

const { subscribe, update } = writable<Toast[]>([]);

let counter = 1;

function push(message: string, type: ToastType = 'info', timeout = 3500, linkUrl?: string, linkLabel?: string) {
  const id = counter++;
  const toast: Toast = { id, type, message, timeout, linkUrl, linkLabel };
  update((list) => [...list, toast]);
  // auto-remove
  setTimeout(() => {
    remove(id);
  }, timeout);
  return id;
}

function remove(id: number) {
  update((list) => list.filter((t) => t.id !== id));
}

export const toasts = { subscribe };
export const toast = {
  show: (message: string, type: ToastType = 'info', timeout?: number) => push(message, type, timeout),
  success: (message: string, timeout?: number) => push(message, 'success', timeout),
  error: (message: string, timeout?: number) => push(message, 'error', timeout),
  info: (message: string, timeout?: number) => push(message, 'info', timeout),
  successWithLink: (message: string, linkUrl: string, linkLabel = 'View', timeout?: number) =>
    push(message, 'success', timeout, linkUrl, linkLabel),
  remove,
};
