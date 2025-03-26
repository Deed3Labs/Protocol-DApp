import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import exportContractResult from "../scripts/export-contract";
import { getDeployArtifact } from "../scripts/utils";

const contractName = "Validator";
const deployValidator: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const namedAccounts = await hre.getNamedAccounts();
  const deployer = namedAccounts.deployer;
  
  // Get ValidatorRegistry address
  const validatorRegistry = getDeployArtifact(hre.network.name, "ValidatorRegistry");
  if (!validatorRegistry) {
    console.log("ValidatorRegistry must be deployed first");
    return;
  }
  
  let proxyAddress = getDeployArtifact(hre.network.name, contractName)?.address;
  const contractFactory = await hre.ethers.getContractFactory("core/Validator");
  
  const defaultRoyaltyPercentage = 250; // 2.5%
  
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
    const result = await hre.upgrades.deployProxy(contractFactory, [
      validatorRegistry.address,
      deployer, // Royalty receiver
      defaultRoyaltyPercentage
    ], {
      initializer: "initialize",
      redeployImplementation: "onchange",
      verifySourceCode: true,
    });
    proxyAddress = await result.getAddress();
    contract = await result.waitForDeployment();
    console.log(`New <<${contractName}>> proxy deployed with address`, proxyAddress);
    
    // Register the validator with the registry
    const validatorRegistryContract = await hre.ethers.getContractAt("ValidatorRegistry", validatorRegistry.address);
    await validatorRegistryContract.registerValidator(proxyAddress, "Default Validator");
  }
  
  const tx = contract.deploymentTransaction();
  const artifacts = await hre.deployments.getExtendedArtifact(contractName);
  exportContractResult(hre, contractName, proxyAddress, artifacts, tx, []);
};

export default deployValidator;

deployValidator.tags = ["Validator", "core"];
deployValidator.dependencies = ["ValidatorRegistry"]; 