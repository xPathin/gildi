import { HardhatRuntimeEnvironment } from "hardhat/types";

export const skipUnlessChain =
    (...chainIds: number[]) =>
    async (hre: HardhatRuntimeEnvironment) => {
        const id = hre.network.config.chainId;
        return !(id && chainIds.includes(id)); // return true to skip
    };
