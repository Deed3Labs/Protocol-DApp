/* eslint-disable @typescript-eslint/no-non-null-assertion */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import exportContractResult from "../scripts/export-contract";
import { getDeployArtifact } from "../scripts/utils";

const contractName = "DeedNFT";
const deployDeedNFT: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const namedAccounts = await hre.getNamedAccounts();
  const deployer = namedAccounts.deployer;
  console.log("Deploying DeedNFT with deployer:", deployer);

  // First deploy ValidatorRegistry and a Default Validator if they don't exist
  const validatorRegistryArtifact = getDeployArtifact(hre.network.name, "ValidatorRegistry");
  const validatorArtifact = getDeployArtifact(hre.network.name, "Validator");
  let validatorRegistryAddress = validatorRegistryArtifact?.address;
  let defaultValidatorAddress = validatorArtifact?.address;

  // Deploy ValidatorRegistry if it doesn't exist
  if (!validatorRegistryAddress) {
    console.log("ValidatorRegistry not found, deploying it first...");
    // Deploy logic for ValidatorRegistry
    // ...
  }

  // Deploy default Validator if it doesn't exist
  if (!defaultValidatorAddress) {
    console.log("Default Validator not found, deploying it first...");
    // Deploy logic for Validator
    // ...
  }

  let proxyAddress = getDeployArtifact(hre.network.name, contractName)?.address;
  const contractFactory = await hre.ethers.getContractFactory("core/DeedNFT");
  let contract;
  
  if (proxyAddress) {
    // Upgrade existing proxy
    const result = await hre.upgrades.upgradeProxy(proxyAddress, contractFactory, {
      redeployImplementation: "onchange",
    });
    contract = await result.waitForDeployment();
    console.log(`<<${contractName}>> upgraded with address ${await result.getAddress()} for proxy`, proxyAddress);
  } else {
    // Deploy new proxy
    // Note: The new DeedNFT initialization requires validator and registry addresses
    const result = await hre.upgrades.deployProxy(contractFactory, [
      defaultValidatorAddress, // Default validator address
      validatorRegistryAddress  // Validator registry address
    ], {
      initializer: "initialize",
      redeployImplementation: "onchange",
      verifySourceCode: true,
    });
    proxyAddress = await result.getAddress();
    contract = await result.waitForDeployment();
    console.log(`New <<${contractName}>> proxy deployed with address`, proxyAddress);
  }
  
  const tx = contract.deploymentTransaction();
  const artifacts = await hre.deployments.getExtendedArtifact(contractName);
  exportContractResult(hre, contractName, proxyAddress, artifacts, tx, []);
};

export default deployDeedNFT;

deployDeedNFT.tags = ["DeedNFT", "core"];
// Remove AccessManager dependency
// deployDeedNFT.dependencies = ["AccessManager"];
