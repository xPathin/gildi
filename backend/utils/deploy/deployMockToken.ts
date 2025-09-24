import { DeployResult } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { MockERC20Token, MockERC20Token__factory } from "../../typechain-types";

export const DEFAULT_MOCK_MINTERS = [
    '0xA663b1B8c2a26575EA99c8a9FD34DA28F08aCaa2', // Patrick Testnet
    '0x3DF03901693308925517FA3d4b1F0Dc88bf6B08F',
    '0xB38E991D598570d4f260f7511eEDd4443620c443',
    '0x2a53F6b12A639ce9405eAe691d012C452Dd00D0b', // TESTNET ROYALTY FUNDS HOLDER
]

export enum DEPLOYMENT_TYPE {
    ERC20,
}

export async function deployMockTokenAsync(hre: HardhatRuntimeEnvironment, mockTokenName: string, deploymentType: DEPLOYMENT_TYPE, ...deploymentArgs: any[]): Promise<DeployResult | undefined> {
    const { deployments, ethers } = hre;
    const { deploy } = deployments;

    const deployer = await ethers.getNamedSignerOrNull("deployer");
    const defaultAdmin = await ethers.getNamedSigner("defaultAdmin");

    if (!deployer) {
        throw Error("Missing deployer account");
    }

    if (!hre.network.tags['localhost'] && !hre.network.tags['testnet']) {
        console.error("Network not supported for mock token deployment");
        return
    }

    const deployment = await deploy(mockTokenName, {
        from: deployer.address,
        log: true,
        args: deploymentArgs
    });

    let contract: MockERC20Token;

    switch (deploymentType) {
        case DEPLOYMENT_TYPE.ERC20:
            contract = MockERC20Token__factory.connect(deployment.address, deployer);
            break;
        default:
            throw Error("Invalid deployment type");
    }

    const minters = DEFAULT_MOCK_MINTERS;
    for (const minter of minters) {
        if (!await contract.hasRole(await contract.MINTER_ROLE(), minter)) {
            console.log(`Granting minter role to ${minter}`);
            await contract.connect(defaultAdmin).grantRole(await contract.MINTER_ROLE(), minter);
        }
    }

    return deployment;
}