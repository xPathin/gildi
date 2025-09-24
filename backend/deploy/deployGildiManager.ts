import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { IGildiManager } from "../typechain-types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;

    const { deployer, proxyAdmin, defaultAdmin, contractAdmin, gildiManager } =
        await getNamedAccounts();
    if (
        !deployer ||
        !proxyAdmin ||
        !defaultAdmin ||
        !contractAdmin ||
        !gildiManager
    ) {
        throw new Error("Missing named accounts");
    }

    const defaultAdminSigner = await hre.ethers.getSigner(defaultAdmin);
    const gildiManagerSigner = await hre.ethers.getSigner(gildiManager);

    const royaltyRightsTokenDeployment =
        await deployments.getOrNull("GildiShareToken");
    if (!royaltyRightsTokenDeployment) {
        throw new Error("GildiShareToken deployment not found");
    }

    const deployment = await deploy("GildiManager", {
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
                        royaltyRightsTokenDeployment.address,
                    ],
                },
            },
        },
    });

    const royaltyRightsTokenContract = await hre.ethers.getContractAt(
        "GildiShareToken",
        royaltyRightsTokenDeployment.address,
        defaultAdminSigner,
    );
    if (
        !(await royaltyRightsTokenContract.hasRole(
            await royaltyRightsTokenContract.GILDI_MANAGER_ROLE(),
            deployment.address,
        ))
    ) {
        await royaltyRightsTokenContract.grantRole(
            await royaltyRightsTokenContract.GILDI_MANAGER_ROLE(),
            deployment.address,
        );
    }
};

func.tags = ["GildiManager"];
func.dependencies = ["GildiShareToken"];
export default func;
