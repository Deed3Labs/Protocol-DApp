import { DeedInfoModel } from "~~/models/deed-info.model";

export const formatMetadataForRenderer = (data: DeedInfoModel) => {
  return {
    name: `${data.propertyDetails.propertyAddress}, ${data.propertyDetails.propertyCity}, ${data.propertyDetails.propertyState}`,
    description: data.propertyDetails.propertyDescription,
    image: data.propertyDetails.propertyImages?.[0]?.fileId,
    attributes: [
      { trait_type: "Asset Type", value: data.propertyDetails.propertyType },
      { trait_type: "Validation Status", value: data.isValidated ? "Validated" : "Unvalidated" },
      // ... other attributes
    ],
    properties: {
      asset_type: data.propertyDetails.propertyType,
      definition: data.propertyDetails.propertyDescription,
      configuration: JSON.stringify(data.propertyDetails),
    }
  };
};
