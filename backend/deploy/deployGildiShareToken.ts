import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { GildiShareToken__factory } from "../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer, proxyAdmin, defaultAdmin, contractAdmin } =
        await getNamedAccounts();
    if (!deployer || !proxyAdmin || !defaultAdmin || !contractAdmin) {
        throw new Error("Missing named accounts");
    }

    const isMainnet = hre.network.tags["mainnet"] || false;
    const urlFieldStaging = !isMainnet ? ".staging" : "";
    //https://localhost:5001/RWA/1075/0/token-metadata/1
    const baseUri = `https://example.com/token-metadata/`;

    const deployment = await deploy("GildiShareToken", {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: "OpenZeppelinTransparentProxy",
            execute: {
                init: {
                    methodName: "initialize",
                    args: [defaultAdmin, contractAdmin, baseUri],
                },
            },
        },
    });

    const contractAdminSigner = await hre.ethers.getSigner(contractAdmin);
    const tokenContract = GildiShareToken__factory.connect(
        deployment.address,
        contractAdminSigner,
    );
    if ((await tokenContract.uri(0)) !== baseUri + "0") {
        await tokenContract.connect(contractAdminSigner).setURI(baseUri);
    }
};

func.tags = ["GildiShareToken", "Token"];
export default func;
