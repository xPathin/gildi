import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
    GildiExchangePaymentAggregator__factory,
    UniswapV3SwapAdapter__factory,
} from "../../../typechain-types";
import { Token } from "../../../constants/tokenAddresses";
import {
    fetchTokenAddress,
    fetchTokenAddressOrNull,
} from "../../../utils/fetchTokenInfo";
import { AddressLike } from "ethers";
import { skipUnlessChain } from "../../../utils/deploy/chainGating";

// Pool fee tiers
const FEE_0_01_PERCENT = 100n; // 0.01%
const FEE_0_05_PERCENT = 500n; // 0.05%
const FEE_0_3_PERCENT = 3000n; // 0.30%
const FEE_1_0_PERCENT = 10000n; // 1.00%

interface RouteConfig {
    sourceToken: Token;
    targetToken: Token;
    route: Token[];
    fees: bigint[];
    doNotReverse?: boolean; // default false
}

interface AdapterConfig {
    router: AddressLike;
    factory: AddressLike;
    routes: RouteConfig[];
}

// ------ GLOBAL SETTINGS ------
const NETWORK_BUY_TOKENS = {
    11155420: [Token.USDC, Token.WNATIVE],
};

const NETWORK_ALLOW_NATIVE_PURCHASE = {
    11155420: true,
};

const ROUTES: { [key: number]: RouteConfig[] } = {
    11155420: [
        // Target: RUST
        // WETH -> USDC -> RUST
        // USDC -> RUST
        {
            sourceToken: Token.WNATIVE,
            targetToken: Token.RUST,
            route: [Token.WNATIVE, Token.USDC, Token.RUST],
            fees: [FEE_0_3_PERCENT, FEE_0_3_PERCENT],
        },
        // USDC -> RUST
        {
            sourceToken: Token.USDC,
            targetToken: Token.RUST,
            route: [Token.USDC, Token.RUST],
            fees: [FEE_0_3_PERCENT],
        },
    ],
};

const ADAPTER_CONFIG: {
    [key: number]: AdapterConfig;
} = {
    11155420: {
        router: "0x94cC0AaC535CCDB3C01d6787D6413C739ae12bc4",
        factory: "0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24",
        routes: ROUTES[11155420],
    },
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer, proxyAdmin, contractAdmin, defaultAdmin } =
        await getNamedAccounts();

    if (!deployer || !proxyAdmin || !defaultAdmin || !contractAdmin) {
        throw new Error("Missing named accounts");
    }

    if (hre.network.config.chainId !== 11155420) {
        console.error(`Chain ID ${hre.network.config.chainId} not supported`);
        return;
    }

    const contractAdminSigner = await ethers.getSigner(contractAdmin);
    if (!contractAdminSigner) {
        throw new Error("Contract admin signer not found");
    }

    const routerAddress = ADAPTER_CONFIG[hre.network.config.chainId].router;
    const factoryAddress = ADAPTER_CONFIG[hre.network.config.chainId].factory;
    if (!routerAddress || !factoryAddress) {
        throw new Error(
            `Missing adapter configuration for chain ID ${hre.network.config.chainId}`,
        );
    }

    const viewQuoterDeployment = await deploy("UniswapV3ViewQuoter", {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: "OpenZeppelinTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [factoryAddress],
                },
            },
        },
    });

    const adapterDeployment = await deploy("UniswapV3SwapAdapter", {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: "OpenZeppelinTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [
                        viewQuoterDeployment.address,
                        routerAddress,
                        defaultAdmin,
                        contractAdmin,
                    ],
                },
            },
        },
    });

    console.log("Configuring UniswapV3SwapAdapter...");
    let adapter = UniswapV3SwapAdapter__factory.connect(
        adapterDeployment.address,
        contractAdminSigner,
    );

    if ((await adapter.quoter()) != viewQuoterDeployment.address) {
        console.log(`Updating quoter to ${viewQuoterDeployment.address}`);
        await adapter.setQuoter(viewQuoterDeployment.address);
    }

    if ((await adapter.router()) != routerAddress) {
        console.log(`Updating router to ${routerAddress}`);
        await adapter.setRouter(routerAddress);
    }

    console.log("Adding routes to UniswapV3SwapAdapter...");

    //
    // STEP 1: Build a map of all desired routes with fees for each forward (source->target)
    //         and (optionally) reverse (target->source).
    //
    interface RouteWithFees {
        path: string[];
        fees: bigint[];
    }

    type UniswapRouteMap = Map<string, RouteWithFees[]>; // Key: "source|target", Value: array of routes with fees
    const forwardMap: UniswapRouteMap = new Map();
    const reverseMap: UniswapRouteMap = new Map();

    for (const routeConfig of ADAPTER_CONFIG[hre.network.config.chainId]
        .routes) {
        const sourceAddr = fetchTokenAddressOrNull(
            routeConfig.sourceToken,
            hre.network.config.chainId,
        );
        const targetAddr = fetchTokenAddressOrNull(
            routeConfig.targetToken,
            hre.network.config.chainId,
        );

        if (!sourceAddr) {
            console.info(
                `Missing source token "${routeConfig.sourceToken}" address for chain ID ${hre.network.config.chainId}. Skipping...`,
            );
            continue;
        }

        if (!targetAddr) {
            console.info(
                `Missing target token "${routeConfig.targetToken}" address for chain ID ${hre.network.config.chainId}. Skipping...`,
            );
            continue;
        }

        // Build the forward route with fees
        const forwardRoute = routeConfig.route.map((t) =>
            fetchTokenAddress(t, hre.network.config.chainId!),
        );
        const forwardFees = [...routeConfig.fees];

        // Store in forwardMap
        const forwardKey = `${sourceAddr.toLowerCase()}|${targetAddr.toLowerCase()}`;
        if (!forwardMap.has(forwardKey)) {
            forwardMap.set(forwardKey, []);
        }
        forwardMap.get(forwardKey)!.push({
            path: forwardRoute,
            fees: forwardFees,
        });

        // If doNotReverse is not set, we also store the reverse route
        if (!routeConfig.doNotReverse) {
            const reverseRoute = [...forwardRoute].reverse();
            const reverseFees = [...forwardFees].reverse();
            const reverseKey = `${targetAddr.toLowerCase()}|${sourceAddr.toLowerCase()}`;
            if (!reverseMap.has(reverseKey)) {
                reverseMap.set(reverseKey, []);
            }
            reverseMap.get(reverseKey)!.push({
                path: reverseRoute,
                fees: reverseFees,
            });
        }
    }

    //
    // STEP 2: For each forwardKey, remove stale routes and add missing ones
    //
    for (const [key, desiredRoutes] of forwardMap.entries()) {
        const [sourceAddr, targetAddr] = key.split("|");

        let existingRoutes = await adapter.listRoutes(sourceAddr, targetAddr);

        // Remove stale
        for (let i = existingRoutes.length - 1; i >= 0; i--) {
            if (
                !desiredRoutes.some((d) =>
                    areRoutesWithFeesEqual(
                        d.path,
                        d.fees,
                        existingRoutes[i].path,
                        existingRoutes[i].fees,
                    ),
                )
            ) {
                console.log(
                    `Removing stale forward route for ${sourceAddr}->${targetAddr}: ${existingRoutes[i].path.join(", ")} with fees [${existingRoutes[i].fees.join(", ")}]`,
                );
                await adapter.removeRoute(sourceAddr, targetAddr, i);
            }
        }

        // Refresh
        existingRoutes = await adapter.listRoutes(sourceAddr, targetAddr);

        // Add missing
        for (const desired of desiredRoutes) {
            if (
                !existingRoutes.some((r) =>
                    areRoutesWithFeesEqual(
                        desired.path,
                        desired.fees,
                        r.path,
                        r.fees,
                    ),
                )
            ) {
                console.log(
                    `Adding forward route for ${sourceAddr}->${targetAddr}: ${desired.path.join(", ")} with fees [${desired.fees.join(", ")}]`,
                );
                await adapter.addRoute(
                    sourceAddr,
                    targetAddr,
                    desired.path,
                    desired.fees,
                );
            }
        }
    }

    //
    // STEP 3: For each reverseKey, remove stale routes and add missing ones
    //
    for (const [key, desiredRoutes] of reverseMap.entries()) {
        const [sourceAddr, targetAddr] = key.split("|");

        let existingRoutes = await adapter.listRoutes(sourceAddr, targetAddr);

        // Remove stale
        for (let i = existingRoutes.length - 1; i >= 0; i--) {
            if (
                !desiredRoutes.some((d) =>
                    areRoutesWithFeesEqual(
                        d.path,
                        d.fees,
                        existingRoutes[i].path,
                        existingRoutes[i].fees,
                    ),
                )
            ) {
                console.log(
                    `Removing stale reverse route for ${sourceAddr}->${targetAddr}: ${existingRoutes[i].path.join(", ")} with fees [${existingRoutes[i].fees.join(", ")}]`,
                );
                await adapter.removeRoute(sourceAddr, targetAddr, i);
            }
        }

        // Refresh
        existingRoutes = await adapter.listRoutes(sourceAddr, targetAddr);

        // Add missing
        for (const desired of desiredRoutes) {
            if (
                !existingRoutes.some((r) =>
                    areRoutesWithFeesEqual(
                        desired.path,
                        desired.fees,
                        r.path,
                        r.fees,
                    ),
                )
            ) {
                console.log(
                    `Adding reverse route for ${sourceAddr}->${targetAddr}: ${desired.path.join(", ")} with fees [${desired.fees.join(", ")}]`,
                );
                await adapter.addRoute(
                    sourceAddr,
                    targetAddr,
                    desired.path,
                    desired.fees,
                );
            }
        }
    }

    console.log("UniswapV3SwapAdapter configured");

    // ------ GILDI EXCHANGE MARKETPLACE AGGREGATOR ------
    const gildiExchangeDeployment =
        await deployments.getOrNull("GildiExchange");
    if (!gildiExchangeDeployment) {
        throw new Error("GildiExchange deployment not found");
    }

    const wNativeToken = fetchTokenAddressOrNull(
        Token.WNATIVE,
        hre.network.config.chainId,
    );
    if (!wNativeToken) {
        throw new Error(
            `WNative token address not found for chain ID ${hre.network.config.chainId}`,
        );
    }

    const aggregatorDeployment = await deploy(
        "GildiExchangePaymentAggregator",
        {
            from: deployer,
            log: true,
            proxy: {
                owner: proxyAdmin,
                proxyContract: "OpenZeppelinTransparentProxy",
                execute: {
                    init: {
                        methodName: "initialize",
                        args: [
                            gildiExchangeDeployment.address,
                            wNativeToken,
                            defaultAdmin,
                            contractAdmin,
                        ],
                    },
                },
            },
        },
    );

    console.log("Configuring aggregator...");
    let aggregator = GildiExchangePaymentAggregator__factory.connect(
        aggregatorDeployment.address,
        contractAdminSigner,
    );

    // ------------------------------------------------------------------
    // 2a) SET Adapters (Remove stale, add new)
    // ------------------------------------------------------------------
    const desiredAdapters = [adapterDeployment.address.toLowerCase()];
    let existingAdapters = await aggregator.getAdapters();

    // Remove stale adapters
    for (let i = existingAdapters.length - 1; i >= 0; i--) {
        const existing = existingAdapters[i].toLowerCase();
        if (!desiredAdapters.includes(existing)) {
            console.log(`Removing stale adapter: ${existing}`);
            // aggregatorAdmin.removeAdapter(IMarketplaceSwapAdapter)
            await aggregator["removeAdapter(address)"](existingAdapters[i]);
        }
    }

    // re-query
    existingAdapters = await aggregator.getAdapters();

    // add new
    for (const desired of desiredAdapters) {
        if (!existingAdapters.map((a) => a.toLowerCase()).includes(desired)) {
            console.log(`Adding new adapter: ${desired}`);
            await aggregator.addAdapter(desired);
        }
    }

    console.log("Adapters updated on GildiExchangePaymentAggregator.");

    // ------------------------------------------------------------------
    // 2b) SET Purchase tokens (Remove stale, add new)
    // ------------------------------------------------------------------
    const desiredPurchaseTokens = NETWORK_BUY_TOKENS[
        hre.network.config.chainId
    ].map((t) => fetchTokenAddress(t, hre.network.config.chainId!));

    let existingPurchaseTokens = await aggregator.getAllowedPurchaseTokens();
    // remove stale
    for (let i = existingPurchaseTokens.length - 1; i >= 0; i--) {
        const existing = existingPurchaseTokens[i].toLowerCase();
        if (
            !desiredPurchaseTokens
                .map((d) => d.toLowerCase())
                .includes(existing)
        ) {
            console.log(
                `Disallowing stale purchase token: ${existingPurchaseTokens[i]}`,
            );
            await aggregator.setAllowedPurchaseToken(
                existingPurchaseTokens[i],
                false,
            );
        }
    }

    // re-query
    existingPurchaseTokens = await aggregator.getAllowedPurchaseTokens();
    // add new
    for (const newToken of desiredPurchaseTokens) {
        const lowerExisting = existingPurchaseTokens.map((e) =>
            e.toLowerCase(),
        );
        if (!lowerExisting.includes(newToken.toLowerCase())) {
            console.log(`Allowing new purchase token: ${newToken}`);
            await aggregator.setAllowedPurchaseToken(newToken, true);
        }
    }

    console.log("Allowed purchase tokens updated.");

    // ------------------------------------------------------------------
    // 2c) SET allowNative if needed
    // ------------------------------------------------------------------
    const networkAllowNative =
        NETWORK_ALLOW_NATIVE_PURCHASE[hre.network.config.chainId];
    const currentAllowNative = await aggregator.getPurchaseAllowNative();
    if (
        networkAllowNative !== undefined &&
        networkAllowNative !== currentAllowNative
    ) {
        console.log(`Updating setPurchaseAllowNative(${networkAllowNative})`);
        await aggregator.setPurchaseAllowNative(networkAllowNative);
    }

    // ------------------------------------------------------------------
    // 2d) SET native token if changed
    // ------------------------------------------------------------------
    const networkNativeToken = ethers.getAddress(
        fetchTokenAddress(Token.WNATIVE, hre.network.config.chainId),
    );
    const currentNativeToken = ethers.getAddress(
        await aggregator.getWrappedNative(),
    );
    if (networkNativeToken !== currentNativeToken) {
        console.log(`Updating setWrappedNative(${networkNativeToken})`);
        await aggregator.setWrappedNative(networkNativeToken);
    }

    console.log("GildiExchangePaymentAggregator fully configured.");

    // ---------------------
    // Helper functions
    // ---------------------
    function areRoutesWithFeesEqual(
        pathA: string[],
        feesA: bigint[],
        pathB: string[],
        feesB: bigint[],
    ): boolean {
        if (pathA.length !== pathB.length) return false;
        if (feesA.length !== feesB.length) return false;

        for (let i = 0; i < pathA.length; i++) {
            if (pathA[i].toLowerCase() !== pathB[i].toLowerCase()) return false;
        }

        for (let i = 0; i < feesA.length; i++) {
            if (feesA[i] !== feesB[i]) return false;
        }

        return true;
    }
};

func.tags = ["UniswapV3PaymentAggregator", "PaymentAggregator"];
func.dependencies = ["GildiExchange"];
func.skip = skipUnlessChain(11155420);
export default func;
