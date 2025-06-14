import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "ethers"; // Direktan import

const deployProviderRegistry: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const applicationFee = ethers.parseEther("0.0001");

  await deploy("ProviderRegistry", {
    from: deployer,
    args: [applicationFee],
    log: true,
    autoMine: true,
  });
};

export default deployProviderRegistry;

deployProviderRegistry.tags = ["ProviderRegistry"];
