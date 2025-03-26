/* 
 * DEPRECATED: AccessManager is now integrated into DeedNFT
 * This file is kept for reference but is no longer used in the deployment process
 */

/* eslint-disable @typescript-eslint/no-non-null-assertion */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import exportContractResult from "../scripts/export-contract";
import { getDeployArtifact } from "../scripts/utils";

const contractName = "AccessManager";
const deployAccessManager: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  console.log("DEPRECATED: AccessManager is now integrated into DeedNFT");
  return;
  
  // The following code is kept for reference only
  /*
  const namedAccounts = await hre.getNamedAccounts();
  const manager = namedAccounts.manager;
  console.log({ manager });
  let proxyAddress = getDeployArtifact(hre.network.name, contractName)?.address;
  const contractFactory = await hre.ethers.getContractFactory(contractName);
  let contract;
  if (proxyAddress) {
    // Migrate
    const result = await hre.upgrades.upgradeProxy(proxyAddress, contractFactory, {
      redeployImplementation: "onchange",
    });
    contract = await result.waitForDeployment();
    console.log(`<<${contractName}>> upgraded with address ${await result.getAddress()} for proxy`, proxyAddress);
  } else {
    // Deploy new proxy
    const result = await hre.upgrades.deployProxy(contractFactory, [manager], {
      initializer: "initialize",
      redeployImplementation: "onchange",
      verifySourceCode: true,
    });
    contract = await result.waitForDeployment();
    proxyAddress = await result.getAddress();
    console.log(`New <<${contractName}>> proxy deployed with address`, proxyAddress);
  }
  const tx = contract.deploymentTransaction();
  const artifacts = await hre.deployments.getExtendedArtifact(contractName);
  exportContractResult(hre, contractName, proxyAddress, artifacts, tx, []);
  */
};

export default deployAccessManager;

// Remove this tag to prevent deployment
// deployAccessManager.tags = [contractName, "core"];
