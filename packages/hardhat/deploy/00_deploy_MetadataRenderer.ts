import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import exportContractResult from "../scripts/export-contract";
import { getDeployArtifact } from "../scripts/utils";

const contractName = "MetadataRenderer";
const deployMetadataRenderer: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const namedAccounts = await hre.getNamedAccounts();
  const deployer = namedAccounts.deployer;
  
  let proxyAddress = getDeployArtifact(hre.network.name, contractName)?.address;
  const contractFactory = await hre.ethers.getContractFactory("core/MetadataRenderer");
  
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
    const result = await hre.upgrades.deployProxy(contractFactory, [deployer], {
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

export default deployMetadataRenderer;

deployMetadataRenderer.tags = ["MetadataRenderer", "core"]; 