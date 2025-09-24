import { Signer } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import hreGlobal from 'hardhat';

export async function getNamedAccount(
    name: string,
    hre?: HardhatRuntimeEnvironment
): Promise<string> {
    const hreToUse = hre ?? hreGlobal;
    const accounts = await hreToUse.getNamedAccounts();
    const account = accounts[name];
    if (!account) {
        throw new Error(`${name} account not found. Please make sure to add it in the hardhat.config.ts file.`);
    }
    return account;
}

export async function getNamedAccountOrNull(
    name: string,
    hre?: HardhatRuntimeEnvironment
): Promise<string | null> {
    const hreToUse = hre ?? hreGlobal;
    const accounts = await hreToUse.getNamedAccounts();
    return accounts[name] ?? null;
}

export async function getNamedSigner(
    name: string,
    hre?: HardhatRuntimeEnvironment
): Promise<Signer> {
    const hreToUse = hre ?? hreGlobal;
    const { ethers } = hreToUse;
    const signer = await ethers.getNamedSignerOrNull(name);
    if (!signer) {
        throw new Error(`${name} signer not found. Please make sure to add it in the hardhat.config.ts file.`);
    }
    return signer;
}

export async function getNamedSignerOrNull(
    name: string,
    hre?: HardhatRuntimeEnvironment
): Promise<Signer | null> {
    const hreToUse = hre ?? hreGlobal;
    const { ethers } = hreToUse;
    return ethers.getNamedSignerOrNull(name);
}