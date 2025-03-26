// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

// Libraries
import "../libraries/StringUtils.sol";
import "../libraries/JSONUtils.sol";

// Interfaces
import "./interfaces/IERC7572.sol";
import "./interfaces/IDeedNFT.sol";

/**
 * @title MetadataRenderer
 * @dev Renders metadata for NFTs with property details
 */
contract MetadataRenderer is Initializable, OwnableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, IERC7572 {
    using StringsUpgradeable for uint256;
    using StringsUpgradeable for address;
    using Base64Upgradeable for bytes;
    using StringUtils for string;
    using JSONUtils for string;

    // Base URI for external links
    string public baseURI;
    
    // Default images for asset types
    mapping(uint8 => string) public assetTypeImageURIs;
    
    // Image for invalidated assets
    string public invalidatedImageURI;
    
    // Replace the three separate detail structs with a single struct and a mapping
    struct AssetDetails {
        // Base details
        string confidenceScore;
        string background_color;
        string animation_url;
        
        // Store all other details as key-value pairs
        mapping(string => string) fields;
        mapping(string => bool) boolFields;
    }

    // Single mapping for all asset types
    mapping(uint256 => AssetDetails) private tokenDetails;
    
    // Token gallery images
    mapping(uint256 => string[]) public tokenGalleryImages;
    
    // Token features
    mapping(uint256 => string[]) public tokenFeatures;
    
    // Token documents
    mapping(uint256 => string[]) public tokenDocumentTypes;
    mapping(uint256 => mapping(string => string)) public tokenDocuments;
    
    // Token custom metadata (JSON string)
    mapping(uint256 => string) public tokenCustomMetadata;
    
    // Events
    event PropertyDetailsUpdated(uint256 indexed tokenId);
    event VehicleDetailsUpdated(uint256 indexed tokenId);
    event EquipmentDetailsUpdated(uint256 indexed tokenId);
    event TokenFeaturesUpdated(uint256 indexed tokenId);
    event TokenDocumentUpdated(uint256 indexed tokenId, string docType);
    event TokenGalleryUpdated(uint256 indexed tokenId);
    event TokenCustomMetadataUpdated(uint256 indexed tokenId);
    event CompatibleDeedContractAdded(address indexed contractAddress);
    event CompatibleDeedContractRemoved(address indexed contractAddress);
    
    IDeedNFT public deedNFT;
    
    // Add this with the other state variables
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    
    // Add these state variables
    mapping(address => bool) public compatibleDeedContracts;
    address[] public deedContractsList;
    
    /**
     * @dev Initializes the contract
     */
    function initialize(string memory _baseURI) public initializer {
        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        
        baseURI = _baseURI;
        
        // Set up roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // Set default invalidated image
        invalidatedImageURI = "ipfs://QmDefaultInvalidatedImageCID";
        
        // Set default asset type images
        assetTypeImageURIs[0] = "ipfs://QmDefaultLandImageCID";
        assetTypeImageURIs[1] = "ipfs://QmDefaultVehicleImageCID";
        assetTypeImageURIs[2] = "ipfs://QmDefaultEstateImageCID";
        assetTypeImageURIs[3] = "ipfs://QmDefaultCommercialEquipmentImageCID";
    }

    /**
     * @dev Authorizes the contract upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Sets the base URI
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }
    
    /**
     * @dev Sets the default image URI for an asset type
     */
    function setAssetTypeImageURI(uint8 assetType, string memory imageURI) external onlyOwner {
        assetTypeImageURIs[assetType] = imageURI;
    }
    
    /**
     * @dev Sets the invalidated image URI
     */
    function setInvalidatedImageURI(string memory imageURI) external onlyOwner {
        invalidatedImageURI = imageURI;
    }
    
    /**
     * @dev Sets custom metadata for a token
     */
    function setTokenCustomMetadata(uint256 tokenId, string memory metadata) external onlyOwner {
        tokenCustomMetadata[tokenId] = metadata;
        emit TokenCustomMetadataUpdated(tokenId);
    }
    
    /**
     * @dev Sets the token gallery
     * @param tokenId ID of the token
     * @param imageUrls Array of image URLs
     */
    function setTokenGallery(uint256 tokenId, string[] memory imageUrls) external onlyOwnerOrValidator(tokenId) {
        require(_exists(tokenId), "MetadataRenderer: Token does not exist");
        _setTokenGallery(tokenId, imageUrls);
    }

    /**
     * @dev Internal function to set the token gallery
     * @param tokenId ID of the token
     * @param imageUrls Array of image URLs
     */
    function _setTokenGallery(uint256 tokenId, string[] memory imageUrls) internal {
        // Clear existing gallery
        delete tokenGalleryImages[tokenId];
        
        // Add new images
        for (uint i = 0; i < imageUrls.length; i++) {
            if (bytes(imageUrls[i]).length > 0) {
                tokenGalleryImages[tokenId].push(imageUrls[i]);
            }
        }
        
        emit TokenGalleryUpdated(tokenId);
    }
    
    /**
     * @dev Gets token gallery images
     */
    function getTokenGallery(uint256 tokenId) external view returns (string[] memory) {
        return tokenGalleryImages[tokenId];
    }
    
    /**
     * @dev Updates asset details for a token
     * @param tokenId ID of the token
     * @param assetType Type of the asset (0=Land, 1=Vehicle, 2=Estate, 3=CommercialEquipment)
     * @param details JSON string containing the details to update
     * @notice Fields not included in the details parameter will remain unchanged
     * @notice Empty string values ("") will be ignored and not update the existing value
     */
    function updateAssetDetails(
        uint256 tokenId,
        uint8 assetType,
        string memory details
    ) external onlyOwnerOrValidator(tokenId) {
        require(_exists(tokenId), "MetadataRenderer: Token does not exist");
        require(bytes(details).length > 0, "MetadataRenderer: Details cannot be empty");
        
        // Check for gallery updates
        string memory galleryJson = JSONUtils.parseJsonField(details, "gallery");
        if (bytes(galleryJson).length > 0) {
            // Parse the gallery JSON array into string[]
            string[] memory imageUrls = JSONUtils.parseJsonArrayToStringArray(galleryJson);
            if (imageUrls.length > 0) {
                _setTokenGallery(tokenId, imageUrls);
            }
        }
        
        // Parse the JSON details and update the appropriate storage based on asset type
        if (assetType == uint8(IDeedNFT.AssetType.Land) || assetType == uint8(IDeedNFT.AssetType.Estate)) {
            _updatePropertyDetails(tokenId, details);
            emit PropertyDetailsUpdated(tokenId);
        } else if (assetType == uint8(IDeedNFT.AssetType.Vehicle)) {
            _updateVehicleDetails(tokenId, details);
            emit VehicleDetailsUpdated(tokenId);
        } else if (assetType == uint8(IDeedNFT.AssetType.CommercialEquipment)) {
            _updateEquipmentDetails(tokenId, details);
            emit EquipmentDetailsUpdated(tokenId);
        } else {
            revert("MetadataRenderer: Unsupported asset type");
        }
    }

    /**
     * @dev Internal function to update property details
     * @param tokenId ID of the token
     * @param detailsJson JSON string containing the details to update
     */
    function _updatePropertyDetails(uint256 tokenId, string memory detailsJson) internal {
        AssetDetails storage details = tokenDetails[tokenId];
        
        // Update base fields if provided
        string memory confidenceScore = JSONUtils.parseJsonField(detailsJson, "confidenceScore");
        if (bytes(confidenceScore).length > 0) {
            details.confidenceScore = confidenceScore;
        }
        
        string memory backgroundColor = JSONUtils.parseJsonField(detailsJson, "background_color");
        if (bytes(backgroundColor).length > 0) {
            details.background_color = backgroundColor;
        }
        
        string memory animationUrl = JSONUtils.parseJsonField(detailsJson, "animation_url");
        if (bytes(animationUrl).length > 0) {
            details.animation_url = animationUrl;
        }
        
        // Update all other fields using a common pattern
        _updateField(details, detailsJson, "country");
        _updateField(details, detailsJson, "state");
        _updateField(details, detailsJson, "county");
        _updateField(details, detailsJson, "city");
        _updateField(details, detailsJson, "streetNumber");
        _updateField(details, detailsJson, "streetName");
        _updateField(details, detailsJson, "parcelNumber");
        _updateField(details, detailsJson, "deed_type");
        _updateField(details, detailsJson, "recording_date");
        _updateField(details, detailsJson, "recording_number");
        _updateField(details, detailsJson, "legal_description");
        _updateField(details, detailsJson, "latitude");
        _updateField(details, detailsJson, "longitude");
        _updateField(details, detailsJson, "acres");
        _updateField(details, detailsJson, "zoning");
        _updateField(details, detailsJson, "zoningCode");
        _updateField(details, detailsJson, "taxValueSource");
        _updateField(details, detailsJson, "taxAssessedValueUSD");
        _updateField(details, detailsJson, "estimatedValueSource");
        _updateField(details, detailsJson, "estimatedMarketValueUSD");
        _updateField(details, detailsJson, "localAppraisalSource");
        _updateField(details, detailsJson, "localAppraisedValueUSD");
        _updateField(details, detailsJson, "buildYear");
        _updateField(details, detailsJson, "map_overlay");
        
        // Update boolean fields
        _updateBoolField(details, detailsJson, "has_water");
        _updateBoolField(details, detailsJson, "has_electricity");
        _updateBoolField(details, detailsJson, "has_natural_gas");
        _updateBoolField(details, detailsJson, "has_sewer");
        _updateBoolField(details, detailsJson, "has_internet");
    }

    /**
     * @dev Helper function to update a field
     */
    function _updateField(AssetDetails storage details, string memory json, string memory fieldName) internal {
        string memory value = JSONUtils.parseJsonField(json, fieldName);
        if (bytes(value).length > 0) {
            details.fields[fieldName] = value;
        }
    }

    /**
     * @dev Helper function to update a boolean field
     */
    function _updateBoolField(AssetDetails storage details, string memory json, string memory fieldName) internal {
        string memory value = JSONUtils.parseJsonField(json, fieldName);
        if (bytes(value).length > 0) {
            details.boolFields[fieldName] = _stringToBool(value);
        }
    }

    /**
     * @dev Internal function to update vehicle details
     * @param tokenId ID of the token
     * @param detailsJson JSON string containing the details to update
     */
    function _updateVehicleDetails(uint256 tokenId, string memory detailsJson) internal {
        // Implementation of _updateVehicleDetails function
    }

    /**
     * @dev Internal function to update equipment details
     * @param tokenId ID of the token
     * @param detailsJson JSON string containing the details to update
     */
    function _updateEquipmentDetails(uint256 tokenId, string memory detailsJson) internal {
        // Implementation of _updateEquipmentDetails function
    }

    /**
     * @dev Helper function to convert a string to a boolean
     * @param value String value to convert
     * @return Boolean representation of the string
     */
    function _stringToBool(string memory value) internal pure returns (bool) {
        bytes memory b = bytes(value);
        return (b.length > 0 && (b[0] == 't' || b[0] == 'T' || b[0] == '1'));
    }

    /**
     * @dev Modifier to check if the caller is the owner or a validator
     * @param tokenId ID of the token
     */
    modifier onlyOwnerOrValidator(uint256 tokenId) {
        require(
            msg.sender == owner() || 
            (address(deedNFT) != address(0) && deedNFT.hasRole(VALIDATOR_ROLE, msg.sender)) ||
            (address(deedNFT) != address(0) && deedNFT.ownerOf(tokenId) == msg.sender),
            "MetadataRenderer: Caller is not owner or validator"
        );
        _;
    }

    /**
     * @dev Checks if a token exists
     * @param tokenId ID of the token to check
     * @return Whether the token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return address(deedNFT) != address(0) && deedNFT.ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Generates name for a token
     */
    function _generateName(uint256 tokenId, uint8 assetType) internal view returns (string memory) {
        if (assetType == uint8(IDeedNFT.AssetType.Land) || assetType == uint8(IDeedNFT.AssetType.Estate)) {
            AssetDetails storage details = tokenDetails[tokenId];
            return string(abi.encodePacked(
                details.fields["streetNumber"], " ", details.fields["streetName"], ", ", 
                details.fields["city"], ", ", details.fields["state"], " #", tokenId.toString()
            ));
        } else if (assetType == uint8(IDeedNFT.AssetType.Vehicle)) {
            // Implementation of _generateName for Vehicle
            AssetDetails storage details = tokenDetails[tokenId];
            return string(abi.encodePacked(
                details.fields["year"], " ", details.fields["make"], " ", 
                details.fields["model"], " #", tokenId.toString()
            ));
        } else if (assetType == uint8(IDeedNFT.AssetType.CommercialEquipment)) {
            // Implementation of _generateName for CommercialEquipment
            AssetDetails storage details = tokenDetails[tokenId];
            return string(abi.encodePacked(
                details.fields["year"], " ", details.fields["manufacturer"], " ", 
                details.fields["model"], " #", tokenId.toString()
            ));
        }
        
        return tokenId.toString();
    }
    
    /**
     * @dev Generates gallery JSON for a token
     */
    function _generateGallery(uint256 tokenId) internal view returns (string memory) {
        string[] memory images = tokenGalleryImages[tokenId];
        if (images.length == 0) {
            return "";
        }
        
        string memory gallery = '"gallery":[';
        
        for (uint i = 0; i < images.length; i++) {
            if (i > 0) {
                gallery = string(abi.encodePacked(gallery, ','));
            }
            gallery = string(abi.encodePacked(gallery, '"', images[i], '"'));
        }
        
        gallery = string(abi.encodePacked(gallery, ']'));
        
        return gallery;
    }
    
    /**
     * @dev Generates attributes for a token
     */
    function _generateAttributes(uint256 tokenId, uint8 assetType, bool isValidated) internal view returns (string memory) {
        string memory attributes = JSONUtils.createTrait("Asset Type", _assetTypeToString(assetType));
        attributes = string(abi.encodePacked(attributes, ',', 
                    JSONUtils.createTrait("Validation Status", isValidated ? "Validated" : "Unvalidated")));
        
        // Add owner address as beneficiary
        if (address(deedNFT) != address(0)) {
            try IDeedNFT(deedNFT).ownerOf(tokenId) returns (address owner) {
                attributes = string(abi.encodePacked(attributes, ',',
                            JSONUtils.createTrait("Beneficiary", address(owner).toHexString())));
            } catch {
                // If token doesn't exist or other error, continue without adding beneficiary
            }
        }
        
        // Add a few key attributes based on asset type
        if (assetType == uint8(IDeedNFT.AssetType.Land) || assetType == uint8(IDeedNFT.AssetType.Estate)) {
            AssetDetails storage details = tokenDetails[tokenId];
            
            // Add only the most important attributes
            attributes = JSONUtils.addTraitIfNotEmpty(attributes, "Country", details.fields["country"]);
            attributes = JSONUtils.addTraitIfNotEmpty(attributes, "State", details.fields["state"]);
            attributes = JSONUtils.addTraitIfNotEmpty(attributes, "City", details.fields["city"]);
        }
        
        return attributes;
    }
    
    /**
     * @dev Generates properties for a token
     */
    function _generateProperties(uint256 tokenId, uint8 assetType, string memory definition, string memory configuration) internal view returns (string memory) {
        // Create a base properties object with minimal fields
        string memory properties = string(abi.encodePacked(
            '{"asset_type":"', _assetTypeToString(assetType), '"'
        ));
        
        // Add validation info
        AssetDetails storage details = tokenDetails[tokenId];
        if (bytes(details.confidenceScore).length > 0) {
            properties = string(abi.encodePacked(properties, 
                ',"validation":{"status":"', details.confidenceScore, '"}'));
        }
        
        // Add definition and configuration if provided
        if (bytes(definition).length > 0) {
            properties = string(abi.encodePacked(properties, ',"definition":', definition));
        }
        
        if (bytes(configuration).length > 0) {
            properties = string(abi.encodePacked(properties, ',"configuration":', configuration));
        }
        
        // Add custom metadata if available
        string memory customMetadata = tokenCustomMetadata[tokenId];
        if (bytes(customMetadata).length > 0) {
            properties = string(abi.encodePacked(properties, ',"custom":', customMetadata));
        }
        
        // Close the properties object
        properties = string(abi.encodePacked(properties, '}'));
        
        return properties;
    }
    
    /**
     * @dev Gets base details for a token
     */
    function _getBaseDetails(uint256 tokenId, uint8 assetType) internal view returns (string memory backgroundColor, string memory animationUrl) {
        if (assetType == uint8(IDeedNFT.AssetType.Land) || assetType == uint8(IDeedNFT.AssetType.Estate)) {
            AssetDetails storage details = tokenDetails[tokenId];
            return (details.background_color, details.animation_url);
        } else if (assetType == uint8(IDeedNFT.AssetType.Vehicle)) {
            // Implementation of _getBaseDetails for Vehicle
        } else if (assetType == uint8(IDeedNFT.AssetType.CommercialEquipment)) {
            // Implementation of _getBaseDetails for CommercialEquipment
        }
        
        return ("", "");
    }
    
    /**
     * @dev Gets image URI for a token
     */
    function _getImageURI(uint256 tokenId, uint8 assetType, bool isValidated) internal view returns (string memory) {
        if (!isValidated) {
            return invalidatedImageURI;
        }
        
        if (tokenGalleryImages[tokenId].length > 0) {
            return tokenGalleryImages[tokenId][0];
        }
        
        return assetTypeImageURIs[assetType];
    }
    
    /**
     * @dev Generates JSON metadata for a token
     * @param tokenId ID of the token
     * @param name Name of the token
     * @param description Description of the token
     * @param imageURI URI of the token image
     * @param backgroundColor Background color for the token
     * @param animationUrl Animation URL for the token
     * @param gallery Gallery of images for the token
     * @param attributes Attributes for the token
     * @param properties Properties for the token
     * @return Base64-encoded JSON metadata
     */
    function _generateJSON(
        uint256 tokenId,
        string memory name,
        string memory description,
        string memory imageURI,
        string memory backgroundColor,
        string memory animationUrl,
        string memory gallery,
        string memory attributes,
        string memory properties
    ) internal pure returns (string memory) {
        // Build minimal JSON
        string memory json = string(abi.encodePacked(
            '{',
            '"name":"', name, '",',
            '"description":"', description, '",',
            '"image":"', imageURI, '",',
            '"token_id":"', tokenId.toString(), '"'
        ));
        
        // Add optional fields only if they exist
        if (bytes(backgroundColor).length > 0) {
            json = string(abi.encodePacked(json, ',"background_color":"', backgroundColor, '"'));
        }
        
        if (bytes(animationUrl).length > 0) {
            json = string(abi.encodePacked(json, ',"animation_url":"', animationUrl, '"'));
        }
        
        if (bytes(gallery).length > 0) {
            json = string(abi.encodePacked(json, ',', gallery));
        }
        
        if (bytes(attributes).length > 0) {
            json = string(abi.encodePacked(json, ',"attributes":[', attributes, ']'));
        }
        
        if (bytes(properties).length > 0) {
            json = string(abi.encodePacked(json, ',"properties":', properties));
        }
        
        // Close JSON and encode
        json = string(abi.encodePacked(json, '}'));
        return string(abi.encodePacked("data:application/json;base64,", Base64Upgradeable.encode(bytes(json))));
    }
    
    /**
     * @dev Generates token URI for a specific token
     * @param tokenContract Address of the token contract
     * @param tokenId ID of the token
     * @return URI for the token metadata
     */
    function tokenURI(address tokenContract, uint256 tokenId) external view override returns (string memory) {
        // Verify the contract is compatible
        require(isCompatibleDeedContract(tokenContract), "MetadataRenderer: Incompatible contract");
        
        // Get asset type from token
        bytes memory assetTypeBytes = IDeedNFT(tokenContract).getTraitValue(tokenId, keccak256("assetType"));
        if (assetTypeBytes.length == 0) {
            return ""; // Invalid token
        }
        
        uint256 assetTypeValue = abi.decode(assetTypeBytes, (uint256));
        uint8 assetType = uint8(assetTypeValue);
        
        // Get validation status
        (bool isValidated, /* address validator */) = IDeedNFT(tokenContract).getValidationStatus(tokenId);
        
        // Get definition and configuration
        bytes memory definitionBytes = IDeedNFT(tokenContract).getTraitValue(tokenId, keccak256("definition"));
        bytes memory configurationBytes = IDeedNFT(tokenContract).getTraitValue(tokenId, keccak256("configuration"));
        
        string memory definition = definitionBytes.length > 0 ? abi.decode(definitionBytes, (string)) : "";
        string memory configuration = configurationBytes.length > 0 ? abi.decode(configurationBytes, (string)) : "";
        
        // Generate metadata components
        string memory name = _generateName(tokenId, assetType);
        string memory attributes = _generateAttributes(tokenId, assetType, isValidated);
        string memory properties = _generateProperties(tokenId, assetType, definition, configuration);
        string memory gallery = _generateGallery(tokenId);
        string memory imageURI = _getImageURI(tokenId, assetType, isValidated);
        
        AssetDetails storage details = tokenDetails[tokenId];
        string memory backgroundColor = details.background_color;
        string memory animationUrl = details.animation_url;
        
        // Generate JSON
        return _generateJSON(
            tokenId,
            name,
            definition,
            imageURI,
            backgroundColor,
            animationUrl,
            gallery,
            attributes,
            properties
        );
    }

    /**
     * @dev Sets features for a token
     * @param tokenId ID of the token
     * @param features Array of feature strings
     */
    function setTokenFeatures(uint256 tokenId, string[] memory features) external onlyOwnerOrValidator(tokenId) {
        require(_exists(tokenId), "MetadataRenderer: Token does not exist");
        
        delete tokenFeatures[tokenId];
        for (uint i = 0; i < features.length; i++) {
            tokenFeatures[tokenId].push(features[i]);
        }
        
        emit TokenFeaturesUpdated(tokenId);
    }

    /**
     * @dev Gets features for a token
     * @param tokenId ID of the token
     * @return Array of feature strings
     */
    function getTokenFeatures(uint256 tokenId) external view returns (string[] memory) {
        return tokenFeatures[tokenId];
    }

    /**
     * @dev Sets a document for a token
     * @param tokenId ID of the token
     * @param docType Type of document
     * @param documentURI URI of the document
     */
    function manageTokenDocument(uint256 tokenId, string memory docType, string memory documentURI, bool isRemove) external onlyOwnerOrValidator(tokenId) {
        require(_exists(tokenId), "MetadataRenderer: Token does not exist");
        
        if (isRemove) {
            // Remove document logic
            for (uint i = 0; i < tokenDocumentTypes[tokenId].length; i++) {
                if (keccak256(bytes(tokenDocumentTypes[tokenId][i])) == keccak256(bytes(docType))) {
                    tokenDocumentTypes[tokenId][i] = tokenDocumentTypes[tokenId][tokenDocumentTypes[tokenId].length - 1];
                    tokenDocumentTypes[tokenId].pop();
                    delete tokenDocuments[tokenId][docType];
                    break;
                }
            }
        } else {
            // Add document logic
            require(bytes(docType).length > 0, "MetadataRenderer: Document type cannot be empty");
            
            bool docTypeExists = false;
            for (uint i = 0; i < tokenDocumentTypes[tokenId].length; i++) {
                if (keccak256(bytes(tokenDocumentTypes[tokenId][i])) == keccak256(bytes(docType))) {
                    docTypeExists = true;
                    break;
                }
            }
            
            if (!docTypeExists) {
                tokenDocumentTypes[tokenId].push(docType);
            }
            
            tokenDocuments[tokenId][docType] = documentURI;
        }
        
        emit TokenDocumentUpdated(tokenId, docType);
    }

    /**
     * @dev Gets a document for a token
     * @param tokenId ID of the token
     * @param docType Type of document
     * @return URI of the document
     */
    function getTokenDocument(uint256 tokenId, string memory docType) external view returns (string memory) {
        return tokenDocuments[tokenId][docType];
    }

    /**
     * @dev Gets all document types for a token
     * @param tokenId ID of the token
     * @return Array of document type strings
     */
    function getTokenDocumentTypes(uint256 tokenId) external view returns (string[] memory) {
        return tokenDocumentTypes[tokenId];
    }

    /**
     * @dev Internal function to add a compatible DeedNFT contract
     */
    function _addCompatibleDeedContract(address contractAddress) internal {
        require(contractAddress != address(0), "MetadataRenderer: Invalid contract address");
        require(!compatibleDeedContracts[contractAddress], "MetadataRenderer: Contract already added");
        
        // Basic interface check
        try IDeedNFT(contractAddress).supportsInterface(type(IERC721Upgradeable).interfaceId) returns (bool supported) {
            require(supported, "MetadataRenderer: Contract does not implement IERC721");
        } catch {
            revert("MetadataRenderer: Contract does not implement IDeedNFT interface");
        }
        
        compatibleDeedContracts[contractAddress] = true;
        deedContractsList.push(contractAddress);
        emit CompatibleDeedContractAdded(contractAddress);
    }

    /**
     * @dev Sets the DeedNFT contract address
     * @param _deedNFT Address of the DeedNFT contract
     */
    function setDeedNFT(address _deedNFT) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_deedNFT != address(0), "MetadataRenderer: Invalid DeedNFT address");
        deedNFT = IDeedNFT(_deedNFT);
        
        // Also add to compatible contracts if not already added
        if (!compatibleDeedContracts[_deedNFT]) {
            _addCompatibleDeedContract(_deedNFT);
        }
    }

    /**
     * @dev Adds or removes a compatible DeedNFT contract
     * @param contractAddress Address of the compatible DeedNFT contract
     */
    function manageCompatibleDeedContract(address contractAddress, bool isAdd) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isAdd) {
            _addCompatibleDeedContract(contractAddress);
        } else {
            require(compatibleDeedContracts[contractAddress], "MetadataRenderer: Contract not in compatible list");
            
            compatibleDeedContracts[contractAddress] = false;
            
            for (uint i = 0; i < deedContractsList.length; i++) {
                if (deedContractsList[i] == contractAddress) {
                    deedContractsList[i] = deedContractsList[deedContractsList.length - 1];
                    deedContractsList.pop();
                    break;
                }
            }
            
            emit CompatibleDeedContractRemoved(contractAddress);
        }
    }

    /**
     * @dev Gets all compatible DeedNFT contracts
     * @return Array of compatible DeedNFT contract addresses
     */
    function getCompatibleDeedContracts() external view returns (address[] memory) {
        return deedContractsList;
    }

    /**
     * @dev Checks if a contract is compatible
     * @param contractAddress Address of the contract to check
     * @return Whether the contract is compatible
     */
    function isCompatibleDeedContract(address contractAddress) public view returns (bool) {
        return compatibleDeedContracts[contractAddress];
    }

    // Helper function to convert asset type to string
    function _assetTypeToString(uint8 assetType) internal pure returns (string memory) {
        if (assetType == uint8(IDeedNFT.AssetType.Land)) return "Land";
        if (assetType == uint8(IDeedNFT.AssetType.Estate)) return "Estate";
        if (assetType == uint8(IDeedNFT.AssetType.Vehicle)) return "Vehicle";
        if (assetType == uint8(IDeedNFT.AssetType.CommercialEquipment)) return "Commercial Equipment";
        return "Unknown";
    }
}