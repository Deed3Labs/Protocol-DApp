import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import exportContractResult from "../scripts/export-contract";
import { getDeployArtifact } from "../scripts/utils";

const contractName = "LeaseAgreement";
const deployLeaseAgreement: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  let proxyAddress = getDeployArtifact(hre.network.name, contractName)?.address;
  const contractFactory = await hre.ethers.getContractFactory(contractName);
  
  // Get necessary contract addresses
  const deedNFT = getDeployArtifact(hre.network.name, "DeedNFT");
  const subdivisionNFT = getDeployArtifact(hre.network.name, "SubdivisionNFT");
  const leaseNFT = getDeployArtifact(hre.network.name, "LeaseNFT");
  const fundsManager = getDeployArtifact(hre.network.name, "FundsManager");
  
  if (!deedNFT || !subdivisionNFT || !leaseNFT || !fundsManager) {
    console.log("Required contracts must be deployed first");
    return;
  }
  
  // HNYT token address - update with the appropriate address for the network
  const hnytAddress = "0x2d467a24095B262787f58ce97d9B130ce7232B57"; // Example address
  
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
      leaseNFT.address,
      hnytAddress,
      deedNFT.address,
      subdivisionNFT.address,
      fundsManager.address,
      // No longer passing AccessManager address
    ], {
      initializer: "initialize",
      redeployImplementation: "onchange",
      verifySourceCode: true,
    });
    proxyAddress = await result.getAddress();
    contract = await result.waitForDeployment();
    console.log(`New <<${contractName}>> proxy deployed with address`, proxyAddress);
    
    // Set the lease agreement address in the LeaseNFT contract
    const leaseNFTContract = await hre.ethers.getContractAt("LeaseNFT", leaseNFT.address);
    await leaseNFTContract.setLeaseAgreementAddress(proxyAddress);
    console.log(`Set LeaseAgreement address in LeaseNFT`);
  }
  
  const tx = contract.deploymentTransaction();
  const artifacts = await hre.deployments.getExtendedArtifact(contractName);
  exportContractResult(hre, contractName, proxyAddress, artifacts, tx, []);
};

export default deployLeaseAgreement;

deployLeaseAgreement.tags = ["LeaseAgreement", "core"];
// Remove AccessManager from dependencies
deployLeaseAgreement.dependencies = ["DeedNFT", "SubdivisionNFT", "LeaseNFT", "FundsManager"];
