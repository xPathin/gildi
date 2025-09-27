import { Network } from "./enums"
import { NetworkConfig } from "./interfaces";

export const NETWORK_CONFIG: { [key in Network]: NetworkConfig } = {
    [Network.OPTIMISM_TESTNET]: {
        rpcUrl: "https://sepolia.optimism.io",
        chainId: 11155420,
        oracleProviderContractAddress: "0x54B6E32b4B83FEEC046296b0AA2e9A583f8f2A7C"
    }
}