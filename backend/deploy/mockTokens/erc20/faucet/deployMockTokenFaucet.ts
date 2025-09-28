import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { getNamedAccount, getNamedSigner } from '../../../../utils/getAccounts';
import { ERC20__factory, MockERC20Token__factory, MockTokenFaucet__factory } from '../../../../typechain-types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    if (!hre.network.tags['localhost'] && !hre.network.tags['testnet']) {
        console.error("Network not supported for mock token faucet deployment");
        return
    }

    const { deployments, getNamedAccounts, ethers } = hre;
    const { deploy } = deployments;

    const deployer = await getNamedAccount('deployer', hre);
    const proxyAdmin = await getNamedAccount('proxyAdmin', hre);
    const contractAdmin = await getNamedSigner('contractAdmin', hre);
    const defaultAdmin = await getNamedSigner('defaultAdmin', hre);

    const mockUSDC = await deployments.getOrNull("MockUSDCToken");
    const mockWETH9 = await deployments.getOrNull("MockWETH9Token");

    const faucetCooldownSeconds = 10;

    var deployment = await deploy('MockTokenFaucet', {
        from: deployer,
        log: true,
        proxy: {
            owner: proxyAdmin,
            proxyContract: 'OpenZeppelinTransparentProxy',
            execute: {
                init: {
                    methodName: "initialize",
                    args: [await contractAdmin.getAddress(), faucetCooldownSeconds, faucetCooldownSeconds],
                },
            },
        },
    });

    const shouldTokenAmounts = {
        tokenAddresses: [mockUSDC?.address, mockWETH9?.address],
        tokenAmounts: [1000, 0.25],
    };

    var contract = MockTokenFaucet__factory.connect(deployment.address, contractAdmin);
    const existingTokenAmounts = await contract.getFaucetTokenBaseAmounts();
    for (let i = 0; i < existingTokenAmounts.tokenAddresses.length; i++) {
        const existingTokenAddress = existingTokenAmounts.tokenAddresses[i];

        const shouldToken = shouldTokenAmounts.tokenAddresses.find((e) => ethers.isAddress(e) && e.toLowerCase() === existingTokenAddress.toLowerCase());
        if (!shouldToken) {
            console.log(`Removing faucet token ${existingTokenAddress}`);
            await contract.removeFaucetToken(existingTokenAddress);
        } else {
            console.log(`Keeping faucet token ${existingTokenAddress}`);
        }
    }

    for (let i = 0; i < shouldTokenAmounts.tokenAddresses.length; i++) {
        const shouldToken = { tokenAddress: shouldTokenAmounts.tokenAddresses[i], tokenAmount: shouldTokenAmounts.tokenAmounts[i] };
        const tokenAddress = shouldToken.tokenAddress;
        const tokenAmount = shouldToken.tokenAmount;

        if (!tokenAddress || !tokenAmount) {
            console.error(`Token address or amount missing for faucet token ${i}`);
            continue;
        }

        const tokenContract = MockERC20Token__factory.connect(tokenAddress, defaultAdmin);

        const tokenDecimals = await tokenContract.decimals();
        const tokenAmountParsed = ethers.parseUnits(tokenAmount.toString(), tokenDecimals);

        const existingTokenAmount = await contract.getFaucetTokenBaseAmount(tokenAddress);

        if (!await tokenContract.hasRole(await tokenContract.MINTER_ROLE(), contract)) {
            console.log(`Granting minter role to faucet for ${tokenAddress}`);
            await tokenContract.connect(defaultAdmin).grantRole(await tokenContract.MINTER_ROLE(), contract);
        }

        if (existingTokenAmount != tokenAmountParsed) {
            console.log(`Updating faucet token ${tokenAddress} to ${tokenAmountParsed} token`);
            await contract.setFaucetToken(tokenAddress, tokenAmountParsed);
        }
    }
}

export default func;
func.tags = ['MockTokenFaucet', 'Faucet', 'Tokens'];
func.dependencies = ["MockTokens"];