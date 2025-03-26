import { cloneDeep } from "lodash-es";
import { FileClient } from "~~/clients/files.client";
import { DeedInfoModel } from "~~/models/deed-info.model";
import { FileFieldKeyLabel } from "~~/models/file.model";
import { pushObjectToIpfs } from "~~/servers/ipfs";
import logger from "~~/services/logger.service";

export const uploadFiles = async (
  fileClient: FileClient,
  authToken: string,
  data: DeedInfoModel,
  files?: File[],
  isJson?: boolean
) => {
  try {
    // Handle file uploads first
    if (files) {
      // Upload files to Pinata
      const fileHashes = await Promise.all(
        files.map(async (file) => {
          const formData = new FormData();
          formData.append("file", file);
          const response = await fileClient.uploadFile(formData);
          return response.hash;
        })
      );
      // Update data with file hashes
      // Implementation depends on your file structure
    }

    // If this is a JSON upload, prepare the metadata
    if (isJson) {
      const metadata = {
        name: `${data.propertyDetails.propertyAddress}`,
        description: data.propertyDetails.propertyDescription,
        image: data.propertyDetails.propertyImages?.[0]?.fileId,
        external_url: `https://app.deed3.io/overview/${data.id}`,
        attributes: [
          { trait_type: "Type", value: data.propertyDetails.propertyType },
          { trait_type: "Address", value: data.propertyDetails.propertyAddress },
        ],
      };
      return metadata;
    }

    return data;
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

  if (includeAll || (data.agreement && (!old || old.agreement !== data.agreement))) {
    files.push(
      new FileFieldKeyLabel({
        key: ["agreement", undefined],
        label: "Agreement",
        multiple: true,
        restricted: true,
      }),
    );
  }

  if (includeAll || (data.process && (!old || old.process !== data.process))) {
    files.push(
      new FileFieldKeyLabel({
        key: ["process", undefined],
        label: "Process",
        multiple: true,
        restricted: true,
      }),
    );
  }

  if (includeAll || (data.process && (!old || old.process !== data.process))) {
    files.push(
      new FileFieldKeyLabel({
        key: ["documentNotorization", undefined],
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
    else if (obj[key] === undefined) delete obj[key]; // or set to null
  });
  return obj;
}
