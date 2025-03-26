import { cloneDeep } from "lodash-es";
import { FileClient } from "~~/clients/files.client";
import { DeedInfoModel } from "~~/models/deed-info.model";
import { FileFieldKey, FileFieldKeyLabel } from "~~/models/file.model";
import { pushObjectToIpfs } from "~~/servers/ipfs";
import logger from "~~/services/logger.service";

// Define the metadata type for Pinata upload
interface DeedMetadata {
  assetType: string;
  definition: string;
  configuration: string;
  owner: string;
}

export const uploadFiles = async (
  fileClient: FileClient,
  authToken: string,
  data: DeedInfoModel,
  files?: File[],
  isJson?: boolean
): Promise<DeedMetadata | DeedInfoModel | null> => {
  try {
    // Handle file uploads first
    if (files) {
      const updatedData = cloneDeep(data);
      // Upload files to Pinata
      const fileHashes = await Promise.all(
        files.map(async (file) => {
          // Create a FileModel object from the File
          const fileModel = {
            id: file.name,
            fileId: file.name,
            owner: data.ownerInformation.walletAddress,
            fileName: file.name,
            fileSize: file.size,
            fileType: file.type,
            fileHash: "",
            fileUrl: URL.createObjectURL(file)
          };
          const response = await fileClient.uploadFile(fileModel, authToken);
          return response.hash;
        })
      );
      // Return the updated DeedInfoModel with file hashes
      return updatedData;
    }

    // If this is a JSON upload, prepare the metadata
    if (isJson) {
      // Create metadata object that matches the contract's expected format
      const metadata: DeedMetadata = {
        assetType: data.propertyDetails.propertyType,
        definition: data.propertyDetails.propertyDescription,
        configuration: JSON.stringify({
          ...data.propertyDetails,
          ownerInformation: data.ownerInformation,
          otherInformation: data.otherInformation
        }),
        owner: data.ownerInformation.walletAddress,
      };
      return metadata;
    }

    return null;
  } catch (error) {
    logger.error({ message: "Error uploading files", error });
    return null;
  }
};

// export async function fetchFileInfos(deedData: DeedInfoModel, authToken?: string) {
//   const files = getSupportedFiles(deedData);
//   await Promise.all(
//     files.map(async ({ key, label, value }) => {
//       try {
//         const fileId = typeof value === "string" ? value : value.fileId;
//         const info = await fileClient.authentify(authToken).getFileInfo(fileId);
//         if (!info) throw new Error(`File ${label} not found`);
//         // @ts-ignore when array, key[2] is the index
//         if (key[2] !== undefined) deedData[key[0]][key[1]][key[2]] = info;
//         // @ts-ignore
//         else deedData[key[0]][key[1]] = info;
//       } catch (error) {
//         const message = "Error getting file info for " + label;
//         notification.error(message);
//         logger.error({ message: "Error getting file info for " + label, error });
//       }
//     }),
//   );

//   return deedData;
// }

export function getSupportedFiles(
  data: DeedInfoModel,
  old?: DeedInfoModel,
  publish: boolean = false,
  isMinted: boolean = false,
  includeAll: boolean = false,
): FileFieldKeyLabel[] {
  const files: FileFieldKeyLabel[] = [];

  // Owner informations files
  if (
    includeAll ||
    (data.ownerInformation.ids && (!old || old.ownerInformation.ids !== data.ownerInformation.ids))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["ownerInformation", "ids"],
        label: "ID or Passport",
        multiple: false,
        restricted: true,
      }),
    );
  }
  if (
    includeAll ||
    (data.ownerInformation.proofBill &&
      (!old || old.ownerInformation.proofBill !== data.ownerInformation.proofBill))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["ownerInformation", "proofBill"],
        label: "Utility Bill or Other Document",
        multiple: false,
        restricted: true,
      }),
    );
  }

  if (data.ownerInformation.ownerType === "legal") {
    if (
      includeAll ||
      (data.ownerInformation.articleIncorporation &&
        (!old ||
          old.ownerInformation.articleIncorporation !== data.ownerInformation.articleIncorporation))
    ) {
      files.push(
        new FileFieldKeyLabel({
          key: ["ownerInformation", "articleIncorporation"],
          label: "Article of Incorporation",
          multiple: false,
          restricted: true,
        }),
      );
    }

    if (
      includeAll ||
      (data.ownerInformation.operatingAgreement &&
        (!old ||
          old.ownerInformation.operatingAgreement !== data.ownerInformation.operatingAgreement))
    ) {
      files.push(
        new FileFieldKeyLabel({
          key: ["ownerInformation", "operatingAgreement"],
          label: "Operating Agreement",
          multiple: false,
          restricted: true,
        }),
      );
    }

    if (
      includeAll ||
      (data.ownerInformation.supportingDoc?.length &&
        (data.ownerInformation.supportingDoc.find(x => !x.fileId) || !old))
    ) {
      files.push(
        new FileFieldKeyLabel({
          key: ["ownerInformation", "supportingDoc"],
          label: "Any other Supporting Documents",
          multiple: false,
          restricted: true,
        }),
      );
    }
  }

  // Property details files
  if (
    includeAll ||
    (data.propertyDetails.propertyImages?.length &&
      (data.propertyDetails.propertyImages.find(x => !x.fileId) || !old))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["propertyDetails", "propertyImages"],
        label: "Property Images",
        multiple: true,
        restricted: publish ? false : !isMinted,
      }),
    );
  }

  if (
    includeAll ||
    (data.propertyDetails.propertyDeedOrTitle &&
      (!old ||
        old.propertyDetails.propertyDeedOrTitle !== data.propertyDetails.propertyDeedOrTitle))
  )
    files.push(
      new FileFieldKeyLabel({
        key: ["propertyDetails", "propertyDeedOrTitle"],
        label: "Deed or Title",
        multiple: false,
        restricted: true,
      }),
    );

  if (
    includeAll ||
    (data.propertyDetails.propertyPurchaseContract &&
      (!old ||
        old.propertyDetails.propertyPurchaseContract !==
          data.propertyDetails.propertyPurchaseContract))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["propertyDetails", "propertyPurchaseContract"],
        label: "Purchase Contract",
        multiple: false,
        restricted: true,
      }),
    );
  }

  if (
    includeAll ||
    (data.propertyDetails.stateFillings && data.propertyDetails.stateFillings.find(x => x.fileId))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["propertyDetails", "stateFillings"],
        label: "State & County Fillings",
        multiple: true,
        restricted: true,
      }),
    );
  }

  // Other information files
  if (
    includeAll ||
    (data.otherInformation.agreement?.length &&
      (!old || old.otherInformation.agreement !== data.otherInformation.agreement))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["otherInformation", "agreement"] as FileFieldKey,
        label: "Agreement",
        multiple: true,
        restricted: true,
      }),
    );
  }

  if (
    includeAll ||
    (data.otherInformation.process?.length &&
      (!old || old.otherInformation.process !== data.otherInformation.process))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["otherInformation", "process"] as FileFieldKey,
        label: "Process",
        multiple: true,
        restricted: true,
      }),
    );
  }

  if (
    includeAll ||
    (data.otherInformation.documentNotorization?.length &&
      (!old || old.otherInformation.documentNotorization !== data.otherInformation.documentNotorization))
  ) {
    files.push(
      new FileFieldKeyLabel({
        key: ["otherInformation", "documentNotorization"] as FileFieldKey,
        label: "Document Notorization",
        multiple: true,
        restricted: true,
      }),
    );
  }

  return files;
}

function cleanObject(obj: any) {
  Object.keys(obj).forEach(key => {
    if (obj[key] && typeof obj[key] === "object") cleanObject(obj[key]);
    else if (obj[key] === undefined) delete obj[key];
  });
  return obj;
}
