import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
    GildiExchangeOrderBook__factory,
    GildiExchange,
    GildiExchange__factory,
} from "../../typechain-types";
import { Token } from "../../constants/tokenAddresses";
import {
    fetchTokenAddress,
    fetchTokenAddressOrNull,
} from "../../utils/fetchTokenInfo";
import { ethers } from "hardhat";
import { AddressLike } from "ethers";

const PRICE_ASK_DECIMALS = 2n;

export const PAYMENT_AGGREGATOR_CONFIG: Record<number, string> = {
    1075: "IotaGildiExchangePaymentAggregator",
    8822: "IotaGildiExchangePaymentAggregator",
    11155420: "GildiExchangePaymentAggregator",
};

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { contractAdmin } = await getNamedAccounts();

    if (!hre.network.config.chainId) {
        throw new Error("Chain ID not configured");
    }

    if (!contractAdmin) {
        throw new Error("Missing Contract Admin account");
    }

    const contractAdminSigner = await ethers.getSigner(contractAdmin);
    if (!contractAdminSigner) {
        throw new Error("Contract Admin signer not found");
    }

    // _gildiPriceOracle: AddressLike | Typed, _askDecimals: BigNumberish | Typed, _orderBook: AddressLike | Typed, _fundManager: AddressLike | Typed, _paymentProcessor: AddressLike | Typed, _paymentAggregator: AddressLike | Typed):
    const gildiExchangeDeployment =
        await deployments.getOrNull("GildiExchange");
    if (!gildiExchangeDeployment) {
        throw new Error("GildiExchange deployment not found");
    }

    const gildiPriceOracleDeployment =
        await deployments.getOrNull("GildiPriceOracle");
    if (!gildiPriceOracleDeployment) {
        throw new Error("GildiPriceOracle deployment not found");
    }

    const orderBookDeployment = await deployments.getOrNull(
        "GildiExchangeOrderBook",
    );
    if (!orderBookDeployment) {
        throw new Error("GildiExchangeOrderBook deployment not found");
    }

    const fundManagerDeployment = await deployments.getOrNull(
        "GildiExchangeFundManager",
    );
    if (!fundManagerDeployment) {
        throw new Error("GildiExchangeFundManager deployment not found");
    }

    const paymentProcessorDeployment = await deployments.getOrNull(
        "GildiExchangePaymentProcessor",
    );
    if (!paymentProcessorDeployment) {
        throw new Error("GildiExchangePaymentProcessor deployment not found");
    }

    const paymentAggregatorDeployment = await deployments.getOrNull(
        PAYMENT_AGGREGATOR_CONFIG[hre.network.config.chainId],
    );
    if (!paymentAggregatorDeployment) {
        throw new Error("PaymentAggregator deployment not found");
    }

    const gildiExchangeContract = GildiExchange__factory.connect(
        gildiExchangeDeployment.address,
        contractAdminSigner,
    );

    const appSettings = (await gildiExchangeContract.getAppEnvironment())
        .settings;

    const gildiExchangeOrderBookContract =
        GildiExchangeOrderBook__factory.connect(
            appSettings.orderBook,
            contractAdminSigner,
        );

    if (appSettings.priceAskDecimals != PRICE_ASK_DECIMALS) {
        console.log(
            "Price ask decimals changed, need to cancel all existing listings.",
        );

        var allReleaseIds = await gildiExchangeContract.getReleaseIds(true);
        for (let i = 0; i < allReleaseIds.length; i++) {
            var release = await gildiExchangeContract.releases(
                allReleaseIds[i],
            );
            while (
                (await gildiExchangeOrderBookContract.listedQuantities(
                    allReleaseIds[i],
                )) > 0
            ) {
                await gildiExchangeContract
                    .connect(contractAdminSigner)
                    .unlistAllListings(allReleaseIds[i], 100);
                console.log(
                    `Batch cancelled listings for release ${allReleaseIds[i]}.`,
                );
            }
        }
    }

    if (
        appSettings.priceAskDecimals != PRICE_ASK_DECIMALS ||
        appSettings.orderBook != orderBookDeployment.address ||
        appSettings.fundManager != fundManagerDeployment.address ||
        appSettings.paymentProcessor != paymentProcessorDeployment.address ||
        appSettings.paymentAggregator != paymentAggregatorDeployment.address
    ) {
        console.log("Updating app environment...");
        await gildiExchangeContract.setup(
            gildiPriceOracleDeployment.address,
            PRICE_ASK_DECIMALS,
            orderBookDeployment.address,
            fundManagerDeployment.address,
            paymentProcessorDeployment.address,
            paymentAggregatorDeployment.address,
        );
    }
};

func.tags = ["SetupGildiExchange"];
func.dependencies = ["GildiExchange", "PaymentAggregator"];
export default func;
