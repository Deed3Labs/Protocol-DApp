import { useScaffoldContractWrite, useScaffoldContractRead } from "../../scaffold-eth";
import { TransactionReceipt } from "viem";
import useDeedClient from "~~/clients/deeds.client";
import useFileClient from "~~/clients/files.client";
import { PropertyTypeOptions } from "~~/constants";
import useWallet from "~~/hooks/useWallet";
import { DeedInfoModel } from "~~/models/deed-info.model";
import { uploadFiles } from "~~/services/file.service";
import logger from "~~/services/logger.service";
import { indexOfLiteral } from "~~/utils/extract-values";
import { notification } from "~~/utils/scaffold-eth";
import { useFundManager } from "../fund-manager/useFundManager.hook";

// Define the metadata type for Pinata upload
interface DeedMetadata {
  assetType: string;
  definition: string;
  configuration: string;
  owner: string;
}

const useDeedMint = (onConfirmed?: (txnReceipt: TransactionReceipt) => void) => {
  const { primaryWallet, authToken } = useWallet();
  const fileClient = useFileClient();
  const registrationsClient = useDeedClient();
  const { handlePayment, feeAmount } = useFundManager();

  const contractWriteHook = useScaffoldContractWrite({
    contractName: "DeedNFT",
    functionName: "mintAsset",
    args: [] as any,
    onBlockConfirmation: onConfirmed,
  });

  // Get default validator address
  const { data: defaultValidator } = useScaffoldContractRead({
    contractName: "ValidatorRegistry",
    functionName: "getDefaultValidator",
  });

  const writeAsync = async (data: DeedInfoModel) => {
    if (!primaryWallet || !authToken) {
      notification.error("No wallet connected");
      return;
    }

    // Handle payment first if crypto payment is selected
    if (data.paymentInformation.paymentType === "crypto" && feeAmount) {
      try {
        await handlePayment("crypto", feeAmount);
      } catch (error) {
        notification.error("Payment failed");
        logger.error({ message: "Payment failed", error });
        return;
      }
    }

    const toastId = notification.loading("Publishing documents...");
    let metadata;
    try {
      // Upload files and prepare metadata
      const result = await uploadFiles(fileClient, authToken, data, undefined, true);
      if (!result || !('assetType' in result)) {
        throw new Error("Failed to prepare metadata");
      }
      metadata = result;
    } catch (error) {
      notification.error("Error while publishing documents");
      logger.error({ message: "[Deed Mint] Error while publishing documents", error });
      return null;
    } finally {
      notification.remove(toastId);
    }

    const mintNotif = notification.info("Minting...", {
      duration: Infinity,
    });
    try {
      // Convert property type to contract enum value
      const assetType = PropertyTypeOptions.findIndex(
        option => option.value === data.propertyDetails.propertyType
      );

      // Mint with metadata
      await contractWriteHook.writeAsync({
        args: [
          data.ownerInformation.walletAddress,
          assetType,
          metadata.assetType,
          metadata.definition,
          metadata.configuration,
          defaultValidator || "0x0000000000000000000000000000000000000000"
        ],
      });

      // Save the current state of published documents
      await registrationsClient.saveDeed(data);
    } catch (error) {
      notification.error("Error while minting deed");
      logger.error({ message: "Error while minting deed", error });
      return;
    } finally {
      notification.remove(mintNotif);
    }
  };

  return { ...contractWriteHook, writeAsync };
};

export default useDeedMint;
