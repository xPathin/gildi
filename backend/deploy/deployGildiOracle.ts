import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const ASSETS = [
    { symbol: "RUST", name: "Rusty Robot Country Club" },
    { symbol: "USDC", name: "USD Coin" },
    { symbol: "USD", name: "US Dollar" },
];

const PAIRS = [
    { base: "RUST", quote: "USD" },
    { base: "USDC", quote: "USD" },
];

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!hre.network.config.chainId) {
        throw new Error("Chain ID not configured");
    }

    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const {
        deployer,
        proxyAdmin,
        defaultAdmin,
        contractAdmin,
        oraclePriceFeeder,
    } = await getNamedAccounts();
    if (!deployer || !proxyAdmin || !defaultAdmin || !contractAdmin) {
        throw new Error("Missing named accounts");
    }

    const contractAdminSigner = await hre.ethers.getSigner(contractAdmin);
    const defaultAdminSigner = await hre.ethers.getSigner(defaultAdmin);

    if (!contractAdminSigner || !defaultAdminSigner) {
        throw new Error("Missing signers");
    }

    const gildiOracleDeployment = await deploy("GildiPriceOracle", {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: "OpenZeppelinTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [defaultAdmin, contractAdmin],
                },
            },
        },
    });

    const gildiPriceProviderDeployment = await deploy("GildiPriceProvider", {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: "OpenZeppelinTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [
                        defaultAdmin,
                        contractAdmin,
                        gildiOracleDeployment.address,
                    ],
                },
            },
        },
    });

    const gildiPriceResolverDeployment = await deploy("GildiPriceResolver", {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: "OpenZeppelinTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [gildiPriceProviderDeployment.address, defaultAdmin],
                },
            },
        },
    });

    if (oraclePriceFeeder) {
        const gildiPriceProviderContract = await hre.ethers.getContractAt(
            "GildiPriceProvider",
            gildiPriceProviderDeployment.address,
            defaultAdminSigner,
        );
        if (
            !(await gildiPriceProviderContract.hasRole(
                await gildiPriceProviderContract.PRICE_FEEDER_ROLE(),
                oraclePriceFeeder,
            ))
        ) {
            console.log(
                `Granting PRICE_FEEDER_ROLE to ${oraclePriceFeeder}...`,
            );
            await gildiPriceProviderContract.grantRole(
                await gildiPriceProviderContract.PRICE_FEEDER_ROLE(),
                oraclePriceFeeder,
            );
        } else {
            console.log(
                `PRICE_FEEDER_ROLE already granted to ${oraclePriceFeeder}`,
            );
        }
    } else {
        console.warn(
            "No oraclePriceFeeder specified, skipping PRICE_FEEDER_ROLE grant",
        );
    }

    // Managing assets based on the ASSETS constant
    const gildiOracleContract = await hre.ethers.getContractAt(
        "GildiPriceOracle",
        gildiOracleDeployment.address,
        contractAdminSigner,
    );
    let gildiOracleAssets = await gildiOracleContract.getAssets();

    // Create a map of existing assets by symbol for easier lookup
    const existingAssetMap = new Map();
    gildiOracleAssets.forEach((asset) => {
        existingAssetMap.set(asset.symbol, asset);
    });

    // Set of assets that should be in the oracle (from ASSETS constant)
    const targetAssetSymbols = new Set(ASSETS.map((asset) => asset.symbol));

    // Add new assets that don't exist in the oracle yet
    for (const asset of ASSETS) {
        if (!existingAssetMap.has(asset.symbol)) {
            console.log(`Adding ${asset.symbol} asset to GildiOracle...`);
            await gildiOracleContract.addAsset(asset.symbol, asset.name);
            console.log(`Added ${asset.symbol} asset to GildiOracle`);
        }
    }

    // Remove assets that are not in the ASSETS constant
    for (const [symbol, asset] of existingAssetMap.entries()) {
        if (!targetAssetSymbols.has(symbol)) {
            console.log(`Removing ${symbol} asset from GildiOracle...`);
            // Check if the asset is used in any pairs before removing
            const allPairs = await gildiOracleContract.getPairs();
            const pairsUsingAsset = allPairs.filter(
                (pair) =>
                    pair.baseAsset.id === asset.id ||
                    pair.quoteAsset.id === asset.id,
            );

            // Delete any pairs using this asset first
            for (const pair of pairsUsingAsset) {
                console.log(
                    `Deleting pair ${pair.baseAsset.symbol}/${pair.quoteAsset.symbol} to remove asset...`,
                );
                await gildiOracleContract.deletePair(pair.pairId);
            }

            await gildiOracleContract.deleteAsset(asset.id);
            console.log(`Removed ${symbol} asset from GildiOracle`);
        }
    }

    // Refresh the assets list after modifications
    gildiOracleAssets = await gildiOracleContract.getAssets();
    const assetsBySymbol = new Map();
    gildiOracleAssets.forEach((asset) => {
        assetsBySymbol.set(asset.symbol, asset);
    });

    // Managing pairs based on the PAIRS constant
    const allPairs = await gildiOracleContract.getPairs();

    // Create a map of existing pairs for easier lookup
    const existingPairMap = new Map();
    allPairs.forEach((pair) => {
        const pairKey = `${pair.baseAsset.symbol}/${pair.quoteAsset.symbol}`;
        existingPairMap.set(pairKey, pair);
    });

    // Add or update pairs from the PAIRS constant
    for (const pair of PAIRS) {
        const baseAsset = assetsBySymbol.get(pair.base);
        const quoteAsset = assetsBySymbol.get(pair.quote);

        if (!baseAsset || !quoteAsset) {
            console.warn(
                `Skipping pair ${pair.base}/${pair.quote} - one or both assets not found`,
            );
            continue;
        }

        const pairKey = `${pair.base}/${pair.quote}`;
        const existingPair = existingPairMap.get(pairKey);

        if (existingPair) {
            // Check if the resolver needs to be updated
            const currentResolver = await gildiOracleContract.getResolver(
                existingPair.pairId,
            );

            if (
                currentResolver.toLowerCase() !==
                gildiPriceResolverDeployment.address.toLowerCase()
            ) {
                console.log(
                    `${pairKey} pair exists but has a different resolver. Updating...`,
                );
                // Delete the existing pair
                await gildiOracleContract.deletePair(existingPair.pairId);
                console.log(`Deleted existing ${pairKey} pair`);

                // Add with the new resolver
                await gildiOracleContract.addPair(
                    baseAsset.id,
                    quoteAsset.id,
                    gildiPriceResolverDeployment.address,
                );
                console.log(
                    `Re-added ${pairKey} pair with new GildiPriceResolver`,
                );
            } else {
                console.log(
                    `${pairKey} pair already set with correct resolver`,
                );
            }
        } else {
            console.log(
                `Adding new pair ${pairKey} with GildiPriceResolver...`,
            );
            await gildiOracleContract.addPair(
                baseAsset.id,
                quoteAsset.id,
                gildiPriceResolverDeployment.address,
            );
            console.log(`Added ${pairKey} pair with GildiPriceResolver`);
        }
    }

    // Remove pairs that are not in the PAIRS constant
    for (const [pairKey, pair] of existingPairMap.entries()) {
        const shouldExist = PAIRS.some(
            (p) => `${p.base}/${p.quote}` === pairKey,
        );

        if (!shouldExist) {
            console.log(`Removing pair ${pairKey} from GildiOracle...`);
            await gildiOracleContract.deletePair(pair.pairId);
            console.log(`Removed ${pairKey} pair from GildiOracle`);
        }
    }
};

func.tags = ["GildiOracle"];
export default func;
