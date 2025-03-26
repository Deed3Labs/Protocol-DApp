import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import exportContractResult from "../scripts/export-contract";
import { getDeployArtifact } from "../scripts/utils";

const contractName = "LeaseNFT";
const deployLeaseNFT: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  let proxyAddress = getDeployArtifact(hre.network.name, contractName)?.address;
  const contractFactory = await hre.ethers.getContractFactory(contractName);
  
  // Get DeedNFT address instead of AccessManager
  const deedNFT = getDeployArtifact(hre.network.name, "DeedNFT");
  if (!deedNFT) {
    console.log("DeedNFT must be deployed first");
    return;
  }
  
  let contract;
  if (proxyAddress) {
    // Upgrade existing proxy
    const result = await hre.upgrades.upgradeProxy(proxyAddress, contractFactory, {
      redeployImplementation: "onchange",
    });
    contract = await result.waitForDeployment();
    console.log(`<<${contractName}>> upgraded with address ${await result.getAddress()} for proxy`, proxyAddress);
  } else {
    // Deploy new proxy with DeedNFT address
    const result = await hre.upgrades.deployProxy(contractFactory, [deedNFT.address], {
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

export default deployLeaseNFT;

deployLeaseNFT.tags = ["LeaseNFT", "core"];
// Update dependency to DeedNFT instead of AccessManager
deployLeaseNFT.dependencies = ["DeedNFT"];
