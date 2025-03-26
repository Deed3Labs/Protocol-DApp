// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";

/**
 * @title IValidator
 * @dev Interface for the Validator contract.
 *      Defines required functionality for asset validation, criteria management,
 *      and fee handling.
 *      
 * Integration:
 * - Used by DeedNFT for asset validation
 * - Used by FundManager for service fee retrieval
 * - Supports operating agreement management
 */
interface IValidator is IAccessControlUpgradeable {
    // ============ Events ============

    /**
     * @dev Emitted when a deed is validated
     * @param tokenId ID of the validated token
     * @param isValid Whether the token is valid
     */
    event DeedValidated(uint256 indexed tokenId, bool isValid);

    /**
     * @dev Emitted when a validation error occurs
     * @param tokenId ID of the token with validation error
     * @param errorMessage Description of the error
     */
    event ValidationError(uint256 indexed tokenId, string errorMessage);

    /**
     * @dev Emitted when a field requirement is added
     * @param assetTypeId ID of the asset type
     * @param criteriaField Name of the criteria field
     * @param definitionField Name of the definition field
     */
    event FieldRequirementAdded(uint256 indexed assetTypeId, string criteriaField, string definitionField);

    /**
     * @dev Emitted when field requirements are cleared
     * @param assetTypeId ID of the asset type
     */
    event FieldRequirementsCleared(uint256 indexed assetTypeId);

    /**
     * @dev Emitted when validation criteria is updated
     * @param assetTypeId ID of the asset type
     * @param criteria New validation criteria
     */
    event ValidationCriteriaUpdated(uint256 indexed assetTypeId, string criteria);

    /**
     * @dev Emitted when the default operating agreement is updated
     * @param uri New operating agreement URI
     */
    event DefaultOperatingAgreementUpdated(string uri);

    /**
     * @dev Emitted when an operating agreement is registered
     * @param uri Operating agreement URI
     * @param name Operating agreement name
     */
    event OperatingAgreementRegistered(string uri, string name);

    /**
     * @dev Emitted when a service fee is updated
     * @param token Address of the token
     * @param fee New fee amount
     */
    event ServiceFeeUpdated(address indexed token, uint256 fee);

    /**
     * @dev Emitted when a token is whitelisted or removed from whitelist
     * @param token Address of the token
     * @param status New whitelist status
     */
    event TokenWhitelistStatusUpdated(address indexed token, bool status);

    /**
     * @dev Emitted when the DeedNFT contract is updated
     * @param newDeedNFT The new DeedNFT contract address
     */
    event DeedNFTUpdated(address indexed newDeedNFT);

    /**
     * @dev Emitted when the primary DeedNFT is updated
     * @param deedNFTAddress Address of the new primary DeedNFT contract
     */
    event PrimaryDeedNFTUpdated(address indexed deedNFTAddress);

    /**
     * @dev Emitted when a compatible DeedNFT is added or removed
     * @param deedNFTAddress Address of the DeedNFT contract
     * @param isCompatible Whether the contract is compatible
     */
    event CompatibleDeedNFTUpdated(address indexed deedNFTAddress, bool isCompatible);

    // ============ Validation Functions ============

    /**
     * @dev Validates a deed NFT
     * @param tokenId ID of the token to validate
     * @return Whether the validation was successful
     */
    function validateDeed(uint256 tokenId) external returns (bool);

    /**
     * @dev Validates a deed NFT's operating agreement
     * @param operatingAgreement URI of the operating agreement
     * @return Whether the operating agreement is valid
     */
    function validateOperatingAgreement(
        string memory operatingAgreement
    ) external view returns (bool);

    /**
     * @dev Checks if an asset type is supported by the validator
     * @param assetTypeId ID of the asset type
     * @return Whether the asset type is supported
     */
    function supportsAssetType(uint256 assetTypeId) external view returns (bool);

    // ============ Operating Agreement Functions ============

    /**
     * @dev Returns the default operating agreement URI
     * @return The default operating agreement URI
     */
    function defaultOperatingAgreement() external view returns (string memory);

    /**
     * @dev Returns the name of an operating agreement
     * @param uri URI of the operating agreement
     * @return Name of the operating agreement
     */
    function operatingAgreementName(string memory uri) external view returns (string memory);

    /**
     * @dev Registers an operating agreement
     * @param uri URI of the operating agreement
     * @param name Name of the operating agreement
     */
    function registerOperatingAgreement(string memory uri, string memory name) external;

    // ============ Service Fee Functions ============

    /**
     * @dev Gets the service fee for a token
     * @param token Address of the token
     * @return The service fee amount
     */
    function getServiceFee(address token) external view returns (uint256);

    /**
     * @dev Sets the service fee for a token
     * @param token Address of the token
     * @param fee Service fee amount
     */
    function setServiceFee(address token, uint256 fee) external;

    /**
     * @dev Adds a token to the whitelist
     * @param token Address of the token to whitelist
     */
    function addWhitelistedToken(address token) external;

    /**
     * @dev Removes a token from the whitelist
     * @param token Address of the token to remove
     */
    function removeWhitelistedToken(address token) external;

    /**
     * @dev Checks if a token is whitelisted
     * @param token Address of the token
     * @return Boolean indicating if the token is whitelisted
     */
    function isTokenWhitelisted(address token) external view returns (bool);

    // ============ Criteria Management Functions ============

    /**
     * @dev Gets the validation criteria for an asset type
     * @param assetTypeId ID of the asset type
     * @return Validation criteria as a JSON string
     */
    function getValidationCriteria(uint256 assetTypeId) external view returns (string memory);

    /**
     * @dev Sets the validation criteria for an asset type
     * @param assetTypeId ID of the asset type
     * @param criteria Validation criteria as a JSON string
     */
    function setValidationCriteria(uint256 assetTypeId, string memory criteria) external;

    /**
     * @dev Clears field requirements for an asset type
     * @param assetTypeId ID of the asset type
     */
    function clearFieldRequirements(uint256 assetTypeId) external;

    /**
     * @dev Adds field requirements for an asset type
     * @param assetTypeId ID of the asset type
     * @param criteriaFields Array of criteria field names
     * @param definitionFields Array of definition field names
     */
    function addFieldRequirementsBatch(
        uint256 assetTypeId,
        string[] memory criteriaFields,
        string[] memory definitionFields
    ) external;

    // ============ DeedNFT Compatibility Functions ============

    /**
     * @dev Sets the primary DeedNFT contract address
     * @param deedNFT Address of the DeedNFT contract
     */
    function setPrimaryDeedNFT(address deedNFT) external;

    /**
     * @dev Adds a compatible DeedNFT contract
     * @param deedNFT Address of the DeedNFT contract
     */
    function addCompatibleDeedNFT(address deedNFT) external;

    /**
     * @dev Removes a compatible DeedNFT contract
     * @param deedNFT Address of the DeedNFT contract
     */
    function removeCompatibleDeedNFT(address deedNFT) external;

    /**
     * @dev Checks if a DeedNFT contract is compatible
     * @param deedNFT Address of the DeedNFT contract
     * @return Boolean indicating if the DeedNFT is compatible
     */
    function isCompatibleDeedNFT(address deedNFT) external view returns (bool);

    /**
     * @dev Returns the token URI for a given token ID
     * @param tokenId ID of the token
     * @return The token URI
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    /**
     * @dev Gets the royalty fee percentage for a token
     * @param tokenId ID of the token
     * @return The royalty fee percentage in basis points (100 = 1%)
     */
    function getRoyaltyFeePercentage(uint256 tokenId) external view returns (uint96);

    /**
     * @dev Sets the royalty fee percentage
     * @param percentage The royalty fee percentage in basis points (100 = 1%)
     */
    function setRoyaltyFeePercentage(uint96 percentage) external;

    /**
     * @dev Gets the royalty receiver address
     * @return The address that receives royalties
     */
    function getRoyaltyReceiver() external view returns (address);

    /**
     * @dev Sets the royalty receiver address
     * @param receiver The address that will receive royalties
     */
    function setRoyaltyReceiver(address receiver) external;
}
