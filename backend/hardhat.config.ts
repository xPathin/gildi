import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-ethers";
import "@solidstate/hardhat-bytecode-exporter";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "@openzeppelin/hardhat-upgrades";

import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
    solidity: {
        compilers: [
            {
                version: "0.8.24",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    viaIR: true,
                },
            },
            {
                version: "0.7.6",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        OPTIMISM_TESTNET: {
            url: "https://optimism-sepolia.core.chainstack.com/c1d29d170ab9f4b5a196892eb755d55b",
            chainId: 11155420,
            accounts: {
                mnemonic: getMnemonic("TESTNET"),
            },
            tags: ["testnet"],
        },
    },
    etherscan: {
        apiKey: {
            OPTIMISM_TESTNET: "FAKE_KEY",
        },
    },
    namedAccounts: {
        deployer: 0,
        proxyAdmin: 1,
        defaultAdmin: 2,
        walletFactoryDeployer: 3,
        contractAdmin: {
            default: 10,
        },
        gildiManager: {
            default: 11,
        },
        oraclePriceFeeder: {
            default: 14,
        },
        royaltyFundsHolder: {
            default: 5,
        },
        walletSystemOperator: {
            default: 15,
        },
        tester: 18,
        marketplaceFeeReceiver: {
            default: 6,
            8822: "0x1D5EDa1B45599dBd9712199B3866f0A9C9885E76",
        },
    },
    abiExporter: {
        path: "./generated",
        runOnCompile: true,
        clear: true,
        flat: false,
    },
    bytecodeExporter: {
        path: "./generated",
        runOnCompile: true,
        clear: true,
        flat: false,
    },
};

function getMnemonic(envName: string): string {
    const prefix = envName.toUpperCase();
    const mnemonic = process.env[`MNEMONIC_${prefix}`] || "";

    if (!mnemonic) {
        console.warn(`Missing MNEMONIC_${prefix} environment variable.`);
    }

    return mnemonic;
}

export default config;
