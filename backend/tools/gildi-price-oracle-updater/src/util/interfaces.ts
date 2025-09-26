import { AddressLike, Wallet } from "ethers";

export interface NetworkConfig {
    rpcUrl: string;
    chainId: number;
    oracleProviderContractAddress: AddressLike;
}

export interface NetworkWalletConfig {
    wallet: Wallet;
    networkConfig: NetworkConfig;
}
