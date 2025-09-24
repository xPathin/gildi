import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { DEPLOYMENT_TYPE, deployMockTokenAsync } from '../../../utils/deploy/deployMockToken';
import { deployments } from 'hardhat';
import { MockERC20Token__factory } from '../../../typechain-types';
import { getNamedSignerOrNull } from '../../../utils/getAccounts';

function getSymbol(chainId: number | undefined): string {
    switch (chainId) {
        default:
            return "";
    }
}

function getName(chainId: number | undefined): string {
    switch (chainId) {
        default:
            return "";
    }
}
    

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { getNamedAccounts } = hre;
    const { defaultAdmin, contractAdmin } = await getNamedAccounts();
    if (!defaultAdmin) {
        throw new Error("Named accounts not found in the network config");
    }

    const mockTokens = [
        {
            name: "MockRUSTToken",
            deploymentType: DEPLOYMENT_TYPE.ERC20,
            deploymentParams: [defaultAdmin],
        },
        {
            name: "MockUSDCToken",
            deploymentType: DEPLOYMENT_TYPE.ERC20,
            deploymentParams: [defaultAdmin],
        },
        {
            name: "MockWETH9Token",
            deploymentType: DEPLOYMENT_TYPE.ERC20,
            deploymentParams: [defaultAdmin, contractAdmin, getName(hre.network.config.chainId),getSymbol(hre.network.config.chainId)],
        },
    ];

    for (const mockToken of mockTokens) {
        console.log(`Deploying ${mockToken.name}`);
        await deployMockTokenAsync(hre, mockToken.name, mockToken.deploymentType, ...mockToken.deploymentParams);
        const deployment = await deployments.getOrNull(mockToken.name);
        const testerSigner = await getNamedSignerOrNull("tester", hre);
        if (deployment) {
            const defaultAdminSigner = await getNamedSignerOrNull("defaultAdmin", hre);
            if(!defaultAdminSigner){
                console.error("Default admin signer not found");
                continue;
            }
            const contract = MockERC20Token__factory.connect(deployment.address, defaultAdminSigner);
            if(testerSigner){
                if(!await contract.hasRole(await contract.MINTER_ROLE(), testerSigner)){
                    console.log(`Granting minter role to tester: ${await testerSigner.getAddress()}`);
                    await contract.connect(defaultAdminSigner).grantRole(await contract.MINTER_ROLE(), testerSigner);
                }
            }
        }else{
            console.error(`Deployment ${mockToken.name} not found`);
            continue;
        }
    }
}

export default func;
func.tags = ['MockTokens', 'Tokens'];