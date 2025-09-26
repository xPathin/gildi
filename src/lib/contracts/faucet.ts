import { config } from '$lib/wagmi/config';
import { writeContract, waitForTransactionReceipt } from '@wagmi/core';
import { ADDRESSES, FaucetAbi } from './addresses';
import type { Address } from 'viem';

export async function requestAllTokens(receiver: Address) {
  const hash = await writeContract(config, {
    abi: FaucetAbi,
    address: ADDRESSES.faucet,
    functionName: 'requestAllTokens',
    args: [receiver],
  });
  const receipt = await waitForTransactionReceipt(config, { hash });
  return receipt;
}
