import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployAppointmentScheduler: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  const providerRegistry = await get("ProviderRegistry");

  await deploy("AppointmentScheduler", {
    from: deployer,
    args: [providerRegistry.address],
    log: true,
    autoMine: true,
  });
};

export default deployAppointmentScheduler;

deployAppointmentScheduler.tags = ["AppointmentScheduler"];
