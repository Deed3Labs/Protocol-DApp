/**
 * DON'T MODIFY OR DELETE THIS SCRIPT (unless you know what you're doing)
 *
 * This script generates the file containing the contracts Abi definitions.
 * These definitions are used to derive the types needed in the custom scaffold-eth hooks, for example.
 * This script should run as the last deploy script.
 *  */

/* eslint-disable @typescript-eslint/no-non-null-assertion */
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import fs from "fs";
import path from "path";

// List of contracts to generate ABIs for
const contractNames = [
  "DeedNFT",
  "FundManager",
  "ValidatorRegistry",
  "Validator",
  "MetadataRenderer",
  "LeaseNFT",
  "LeaseAgreement",
  "SubdivisionNFT"
];

// Define networks
const networks = ["localhost", "sepolia", "polygon", "arbitrum"];

function generateImportLine(contractName: string, network: string): string {
  return `import ${contractName}${network.charAt(0).toUpperCase() + network.slice(1)}Artifact from "../deployments/${network}/${contractName}.json";`;
}

function generateExportLine(contractName: string, network: string): string {
  const networkMap = {
    localhost: "31337",
    sepolia: "11155111",
    polygon: "137",
    arbitrum: "42161"
  };
  const chainId = networkMap[network as keyof typeof networkMap];
  const varName = `${contractName}${network.charAt(0).toUpperCase() + network.slice(1)}`;
  return `    ${chainId}: {
      ${contractName}: ${varName}Artifact,
    },`;
}

function capitalizeFirstLetter(string: string): string {
  return string.charAt(0).toUpperCase() + string.slice(1);
}

const generateTsAbis: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  console.log("📝 Generating TypeScript interfaces for contract ABIs...");

  try {
    const deployedContractsDir = path.join(__dirname, "../../nextjs/contracts");
    if (!fs.existsSync(deployedContractsDir)) {
      fs.mkdirSync(deployedContractsDir, { recursive: true });
    }

    // Start building TypeScript file content
    let content = `// Auto-generated file from generateTsAbis.ts
// Do not modify this file manually\n\n`;

    // Add imports for all contract artifacts
    for (const network of networks) {
      for (const contractName of contractNames) {
        // Check if the contract deployment exists for this network
        const deploymentPath = path.join(__dirname, `../deployments/${network}/${contractName}.json`);
        if (fs.existsSync(deploymentPath)) {
          content += generateImportLine(contractName, network) + "\n";
        }
      }
    }

    content += `\nconst deployedContracts = {\n`;

    // Add exports for each network
    for (const network of networks) {
      const networkMap = {
        localhost: "31337",
        sepolia: "11155111",
        polygon: "137",
        arbitrum: "42161"
      };
      const chainId = networkMap[network as keyof typeof networkMap];
      
      content += `  ${chainId}: {\n`;
      
      // Add each contract if it exists for this network
      for (const contractName of contractNames) {
        const deploymentPath = path.join(__dirname, `../deployments/${network}/${contractName}.json`);
        if (fs.existsSync(deploymentPath)) {
          content += `    ${contractName}: ${contractName}${capitalizeFirstLetter(network)}Artifact,\n`;
        }
      }
      
      content += `  },\n`;
    }

    content += `} as const;\n\n`;

    // Add type exports
    content += `// Type definitions\n`;
    content += `export type ChainId = keyof typeof deployedContracts;\n`;
    content += `export type ContractName = keyof typeof deployedContracts[ChainId];\n`;
    content += `export type DeployedContract = (typeof deployedContracts)[ChainId][ContractName];\n\n`;

    content += `export default deployedContracts;\n`;

    // Generate external-contracts.ts file
    const externalContractsPath = path.join(deployedContractsDir, "deployedContracts.ts");
    fs.writeFileSync(externalContractsPath, content);

    // Generate type declarations for contract functions
    for (const contractName of contractNames) {
      // Find the first network that has this contract deployed
      let contractAbi = null;
      for (const network of networks) {
        const deploymentPath = path.join(__dirname, `../deployments/${network}/${contractName}.json`);
        if (fs.existsSync(deploymentPath)) {
          const artifact = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));
          contractAbi = artifact.abi;
          break;
        }
      }

      if (contractAbi) {
        // Generate contract type file
        let contractTypesContent = `// Auto-generated contract types for ${contractName}\n\n`;
        contractTypesContent += `export interface ${contractName}Interface {\n`;
        
        // Extract function definitions from ABI
        const functionItems = contractAbi.filter((item: any) => item.type === "function");
        
        for (const func of functionItems) {
          contractTypesContent += `  ${func.name}(`;
          
          // Add input parameters
          if (func.inputs && func.inputs.length > 0) {
            contractTypesContent += func.inputs.map((input: any, i: number) => 
              `${input.name || `arg${i}`}: ${mapSolidityTypeToTS(input.type)}`
            ).join(", ");
          }
          
          contractTypesContent += `): Promise<`;
          
          // Add output parameters
          if (func.outputs && func.outputs.length > 0) {
            if (func.outputs.length === 1) {
              contractTypesContent += mapSolidityTypeToTS(func.outputs[0].type);
            } else {
              contractTypesContent += `[${func.outputs.map((output: any) => 
                mapSolidityTypeToTS(output.type)
              ).join(", ")}]`;
            }
          } else {
            contractTypesContent += "void";
          }
          
          contractTypesContent += `>;\n`;
        }
        
        contractTypesContent += `}\n`;
        
        // Write to file
        const contractTypesPath = path.join(deployedContractsDir, `${contractName}.types.ts`);
        fs.writeFileSync(contractTypesPath, contractTypesContent);
      }
    }

    console.log("✅ TypeScript interfaces generated successfully");
    
  } catch (error) {
    console.error("Error generating TypeScript interfaces:", error);
  }
};

// Helper function to map Solidity types to TypeScript types
function mapSolidityTypeToTS(solidityType: string): string {
  if (solidityType.includes("int") || solidityType.includes("uint")) {
    return "bigint";
  } else if (solidityType === "bool") {
    return "boolean";
  } else if (solidityType === "string" || solidityType === "bytes" || solidityType.includes("bytes")) {
    return "string";
  } else if (solidityType === "address") {
    return "string";
  } else if (solidityType.includes("[]")) {
    const baseType = solidityType.substring(0, solidityType.length - 2);
    return `${mapSolidityTypeToTS(baseType)}[]`;
  } else {
    return "any"; // For complex types, structs, etc.
  }
}

export default generateTsAbis;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags generateTsAbis
generateTsAbis.tags = ["GenerateTS"];

generateTsAbis.runAtTheEnd = true;
