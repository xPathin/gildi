import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
    GildiExchangePaymentProcessor__factory,
    GildiExchange__factory,
    GildiManager__factory,
    GildiPriceOracle__factory,
    IGildiExchange,
} from "../../typechain-types";
import { Token } from "../../constants/tokenAddresses";
import { fetchTokenAddressOrNull } from "../../utils/fetchTokenInfo";

const GLOBAL_FEE_PERCENTAGE = 300; // 3%
const GLOBAL_FEE_BURN_PERCENTAGE = 1000; // 10%

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const {
        deployer,
        proxyAdmin,
        contractAdmin,
        defaultAdmin,
        gildiManager,
        marketplaceFeeReceiver,
    } = await getNamedAccounts();

    if (!hre.network.config.chainId) {
        throw new Error("Chain ID not configured");
    }

    if (
        !deployer ||
        !proxyAdmin ||
        !defaultAdmin ||
        !contractAdmin ||
        !gildiManager ||
        !marketplaceFeeReceiver
    ) {
        throw new Error("Missing named accounts");
    }

    if (GLOBAL_FEE_PERCENTAGE > 1000 || GLOBAL_FEE_BURN_PERCENTAGE > 1000) {
        throw new Error(
            "Global fee percentage or burn percentage is greater than 10%, config error?",
        );
    }

    const contractAdminSigner = await ethers.getSigner(contractAdmin);
    const defaultAdminSigner = await ethers.getSigner(defaultAdmin);
    const marketplaceManagerSigner = await ethers.getSigner(gildiManager);

    if (
        !contractAdminSigner ||
        !defaultAdminSigner ||
        !marketplaceManagerSigner
    ) {
        throw new Error("Missing signers");
    }

    const rustTokenAddress = fetchTokenAddressOrNull(
        Token.RUST,
        hre.network.config.chainId,
    );
    if (!rustTokenAddress) {
        throw new Error(
            `RUST token address not found for chain ID ${hre.network.config.chainId}`,
        );
    }

    const usdcTokenAddress = fetchTokenAddressOrNull(
        Token.USDC,
        hre.network.config.chainId,
    );
    if (!usdcTokenAddress) {
        throw new Error(
            `USDC token address not found for chain ID ${hre.network.config.chainId}`,
        );
    }

    const gildiManagerDeployment = await deployments.getOrNull("GildiManager");
    if (!gildiManagerDeployment) {
        throw new Error("GildiManager deployment not found");
    }

    const gildiPriceOracleDeployment =
        await deployments.getOrNull("GildiPriceOracle");
    if (!gildiPriceOracleDeployment) {
        throw new Error("GildiPriceOracle deployment not found");
    }

    // Deploy contracts
    // 1. GildiExchange
    // address _initialDefaultAdmin,
    // address _initialAdmin,
    // address _initialMarketplaceManager,
    // IGildiManager _gildiManager,
    // IERC20 _marketplaceCurrency
    const gildiExchangeV2Deployment = await deploy("GildiExchange", {
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
                        gildiManager,
                        gildiManagerDeployment.address,
                        usdcTokenAddress,
                    ],
                },
            },
        },
    });

    // 2. GildiExchangeOrderBook
    const gildiExchangeOrderBookDeployment = await deploy(
        "GildiExchangeOrderBook",
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
                            gildiExchangeV2Deployment.address,
                            gildiManagerDeployment.address,
                        ],
                    },
                },
            },
        },
    );

    // 3. GildiExchangeFundManager
    const gildiExchangeFundManagerDeployment = await deploy(
        "GildiExchangeFundManager",
        {
            from: deployer,
            log: true,
            proxy: {
                owner: proxyAdmin,
                proxyContract: "OpenZeppelinTransparentProxy",
                execute: {
                    init: {
                        methodName: "initialize",
                        args: [gildiExchangeV2Deployment.address],
                    },
                },
            },
        },
    );

    // 4. GildiExchangePaymentProcessor
    const gildiExchangePaymentProcessorDeployment = await deploy(
        "GildiExchangePaymentProcessor",
        {
            from: deployer,
            log: true,
            proxy: {
                owner: proxyAdmin,
                proxyContract: "OpenZeppelinTransparentProxy",
                execute: {
                    init: {
                        methodName: "initialize",
                        args: [gildiExchangeV2Deployment.address],
                    },
                },
            },
        },
    );

    const gildiManagerContract = GildiManager__factory.connect(
        gildiManagerDeployment.address,
        defaultAdminSigner,
    );
    const gildiExchangeV2Contract = GildiExchange__factory.connect(
        gildiExchangeV2Deployment.address,
        contractAdminSigner,
    );
    const gildiPriceOracleContract = GildiPriceOracle__factory.connect(
        gildiPriceOracleDeployment.address,
        defaultAdminSigner,
    );
    const gildiExchangePaymentProcessorContract =
        GildiExchangePaymentProcessor__factory.connect(
            gildiExchangePaymentProcessorDeployment.address,
            contractAdminSigner,
        );

    const gildiManagerMarketplaceRole =
        await gildiManagerContract.MARKETPLACE_ROLE();
    if (
        !(await gildiManagerContract.hasRole(
            gildiManagerMarketplaceRole,
            gildiExchangeV2Deployment.address,
        ))
    ) {
        console.log(`Granting MARKETPLACE_ROLE to GildiExchange...`);
        await gildiManagerContract.grantRole(
            gildiManagerMarketplaceRole,
            gildiExchangeV2Deployment.address,
        );
        console.log(`Granted MARKETPLACE_ROLE to GildiExchange`);
    }
    if (
        !(await gildiManagerContract.hasRole(
            gildiManagerMarketplaceRole,
            gildiExchangeOrderBookDeployment.address,
        ))
    ) {
        console.log(`Granting MARKETPLACE_ROLE to GildiExchangeOrderBook...`);
        await gildiManagerContract.grantRole(
            gildiManagerMarketplaceRole,
            gildiExchangeOrderBookDeployment.address,
        );
        console.log(`Granted MARKETPLACE_ROLE to GildiExchangeOrderBook`);
    }

    // Set fees
    const fees: IGildiExchange.FeeDistributionStruct[] = [
        {
            feeReceiver: {
                receiverAddress: marketplaceFeeReceiver,
                value: GLOBAL_FEE_PERCENTAGE,
                payoutCurrency: usdcTokenAddress,
            },
            subFeeReceivers: [
                {
                    receiverAddress: ethers.ZeroAddress,
                    value: GLOBAL_FEE_BURN_PERCENTAGE,
                    payoutCurrency: rustTokenAddress,
                },
            ],
        },
    ];
    const existingFees = (await gildiExchangeV2Contract.getAppEnvironment())
        .settings.fees;
    if (
        existingFees.length == 0 ||
        existingFees.length != fees.length ||
        existingFees[0].feeReceiver.receiverAddress !=
            fees[0].feeReceiver.receiverAddress ||
        existingFees[0].feeReceiver.value != fees[0].feeReceiver.value ||
        existingFees[0].feeReceiver.payoutCurrency !=
            fees[0].feeReceiver.payoutCurrency ||
        existingFees[0].subFeeReceivers.length !=
            fees[0].subFeeReceivers.length ||
        existingFees[0].subFeeReceivers[0].receiverAddress !=
            fees[0].subFeeReceivers[0].receiverAddress ||
        existingFees[0].subFeeReceivers[0].value !=
            fees[0].subFeeReceivers[0].value ||
        existingFees[0].subFeeReceivers[0].payoutCurrency !=
            fees[0].subFeeReceivers[0].payoutCurrency
    ) {
        console.log(`Fees changed, setting fees...`);
        await gildiExchangeV2Contract.setFees(fees);
    }

    // Get the feed id's for RUST/USD and USDC/USD pairs from gildi oracle.
    const gildiOraclePairs = await gildiPriceOracleContract.getPairs();
    // rustUsdPairId // Find where baseAsset.symbol == 'RUST' and quoteAsset.symbol == 'USD'
    // usdcUsdPairId // Find where baseAsset.symbol == 'USDC' and quoteAsset.symbol == 'USD'
    const rustUsdPairId = gildiOraclePairs.find(
        (pair) =>
            pair.baseAsset.symbol === "RUST" &&
            pair.quoteAsset.symbol === "USD",
    )?.pairId;
    const usdcUsdPairId = gildiOraclePairs.find(
        (pair) =>
            pair.baseAsset.symbol === "USDC" &&
            pair.quoteAsset.symbol === "USD",
    )?.pairId;

    if (!rustUsdPairId || !usdcUsdPairId) {
        throw new Error("RUST/USD or USDC/USD feed not found");
    }

    const priceFeeds = [
        { currency: rustTokenAddress, feedId: rustUsdPairId },
        { currency: usdcTokenAddress, feedId: usdcUsdPairId },
    ];

    for (const feed of priceFeeds) {
        const existingFeedId =
            await gildiExchangePaymentProcessorContract.getPriceFeedId(
                feed.currency,
            );
        if (existingFeedId != feed.feedId) {
            console.log(
                `Setting price feed for ${feed.currency} to ${feed.feedId}...`,
            );
            await gildiExchangePaymentProcessorContract.setPriceFeedId(
                feed.currency,
                feed.feedId,
            );
            console.log(
                `Set price feed for ${feed.currency} to ${feed.feedId}`,
            );
        }
    }

    // refetch and delete old feeds
    const existingFeeds =
        await gildiExchangePaymentProcessorContract.getPriceFeeds();
    for (const feed of existingFeeds) {
        if (!priceFeeds.some((p) => p.currency === feed.currency)) {
            console.log(`Removing price feed for ${feed.currency}...`);
            await gildiExchangePaymentProcessorContract.removePriceFeedId(
                feed.currency,
            );
            console.log(`Removed price feed for ${feed.currency}`);
        }
    }

    // Fix any potential marketplace currency mismatch.
    if (
        (
            await gildiExchangeV2Contract.getAppEnvironment()
        ).settings.marketplaceCurrency.toLowerCase() !=
        usdcTokenAddress.toLowerCase()
    ) {
        console.log(`Setting marketplace currency to ${usdcTokenAddress}...`);
        await gildiExchangeV2Contract.setMarketplaceCurrency(usdcTokenAddress);
    }
};

func.tags = ["GildiExchange"];
func.dependencies = ["GildiManager", "GildiOracle"];
export default func;
