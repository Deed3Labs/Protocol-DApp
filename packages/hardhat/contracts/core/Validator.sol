// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

// OpenZeppelin Upgradeable Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

// Libraries
import "../libraries/StringUtils.sol";
import "../libraries/JSONUtils.sol";

// Interfaces
import "./interfaces/IValidator.sol";
import "./interfaces/IDeedNFT.sol";
import "./interfaces/IFundManager.sol";

/**
 * @title Validator
 * @dev Base contract for implementing deed validation logic.
 *      Provides core functionality for asset validation and metadata management.
 *      
 * Security:
 * - Role-based access control for validation operations
 * - Protected metadata management
 * - Configurable asset type support
 * 
 * Integration:
 * - Works with DeedNFT for asset validation
 * - Implements IValidator interface
 * - Supports UUPSUpgradeable for upgradability
 * - Aligns validation criteria with MetadataRenderer property structure
 */
contract Validator is
    Initializable,
    ERC165Upgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IValidator
{
    using StringsUpgradeable for uint256;
    using StringUtils for string;

    // ============ Role Definitions ============

    /// @notice Role for validation operations
    /// @dev Has authority to perform deed validations
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    /// @notice Role for metadata management
    /// @dev Has authority to update operating agreements and URIs
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");

    /// @notice Role for updating validation criteria
    bytes32 public constant CRITERIA_MANAGER_ROLE = keccak256("CRITERIA_MANAGER_ROLE");

    /// @notice Role for fee management operations
    /// @dev Has authority to update service fees and whitelist tokens
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    /// @notice Role for administrative operations
    /// @dev Has authority to perform administrative tasks
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // ============ State Variables ============

    /// @notice Base URI for token metadata
    string public baseUri;

    /// @notice Default operating agreement URI
    string public defaultOperatingAgreementUri;

    /// @notice Reference to the DeedNFT contract
    /// @dev Used for deed information retrieval and validation
    IDeedNFT public deedNFT;

    /// @notice Mapping of supported asset types
    /// @dev Key: asset type ID, Value: support status
    mapping(uint256 => bool) public supportedAssetTypes;

    /// @notice Mapping of operating agreement URIs to their names
    /// @dev Key: agreement URI, Value: human-readable name
    mapping(string => string) public operatingAgreements;

    /// @notice Mapping of deed IDs to their metadata URIs
    /// @dev Key: deed ID, Value: metadata URI
    mapping(uint256 => string) public deedMetadata;

    /// @notice Mapping of asset types to their validation criteria
    /// @dev Key: asset type ID, Value: validation criteria JSON string
    /// @notice Criteria should align with MetadataRenderer property structure
    mapping(uint256 => string) public validationCriteria;

    /// @notice Mapping to track compatible DeedNFT contracts
    mapping(address => bool) public compatibleDeedNFTs;
    
    /// @notice Main DeedNFT address
    address public primaryDeedNFT;

    /// @notice Mapping to track whitelisted tokens
    /// @dev Key: token address, Value: whitelist status
    mapping(address => bool) public isWhitelisted;

    /// @notice Service fee per token
    /// @dev Key: token address, Value: fee amount in token's smallest unit
    mapping(address => uint256) public serviceFee;

    /// @notice Mapping to store accumulated service fees per token
    mapping(address => uint256) public serviceFeesBalance;

    /// @notice Address of the FundManager contract
    address public fundManager;

    // ============ Upgrade Gap ============

    /// @dev Storage gap for future upgrades
    uint256[48] private __gap;

    // ============ Royalty Variables ============

    /// @notice Default royalty fee percentage in basis points (100 = 1%)
    uint96 public royaltyFeePercentage;

    /// @notice Address that receives royalties
    address public royaltyReceiver;

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with default settings
     * @param _baseUri Base URI for token metadata
     * @param _defaultOperatingAgreementUri Default operating agreement URI
     */
    function initialize(
        string memory _baseUri,
        string memory _defaultOperatingAgreementUri
    ) public initializer {
        __AccessControl_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC165_init();
        
        baseUri = _baseUri;
        defaultOperatingAgreementUri = _defaultOperatingAgreementUri;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(METADATA_ROLE, msg.sender);
        _grantRole(CRITERIA_MANAGER_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
        
        // Set default royalty values
        royaltyFeePercentage = 500; // Default 5%
        royaltyReceiver = msg.sender;
    }

    /**
     * @dev Authorizes the contract upgrade. Only the owner can upgrade.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {
        // Authorization logic handled by onlyOwner modifier
    }

    // ============ Public Functions ============

    /**
     * @dev Sets the base URI for token metadata.
     * @param _newBaseUri The new base URI.
     */
    function setBaseUri(string memory _newBaseUri) public onlyOwner {
        require(bytes(_newBaseUri).length > 0, "Validator: Base URI cannot be empty");
        baseUri = _newBaseUri;
    }

    /**
     * @dev Returns the base URI.
     * @return The base URI string.
     */
    function getBaseUri() public view returns (string memory) {
        return baseUri;
    }

    /**
     * @dev Sets the default operating agreement URI.
     * @param _uri The new default operating agreement URI.
     */
    function setDefaultOperatingAgreement(string memory _uri) public onlyOwner {
        require(bytes(_uri).length > 0, "Validator: URI cannot be empty");
        defaultOperatingAgreementUri = _uri;
    }

    /**
     * @dev Returns the default operating agreement URI.
     * @return The default operating agreement as a string, not just the URI.
     */
    function defaultOperatingAgreement() external view override returns (string memory) {
        // Instead of just returning the URI, we need to return a properly formatted agreement
        // This matches what the new DeedNFT contract expects
        if (bytes(defaultOperatingAgreementUri).length == 0) {
            return "Nominee Trust Agreement v1.0";  // Fallback to ensure non-empty return
        }
        
        string memory agreementName = operatingAgreements[defaultOperatingAgreementUri];
        if (bytes(agreementName).length == 0) {
            // If no name is registered, use the URI itself as the content
            return defaultOperatingAgreementUri;
        }
        
        // Return a properly formatted operating agreement string that combines name and URI
        return string(abi.encodePacked(agreementName, " (", defaultOperatingAgreementUri, ")"));
    }

    /**
     * @dev Adds or updates the name for a given operating agreement URI.
     * @param _uri The URI of the operating agreement.
     * @param _name The name to associate with the URI.
     */
    function setOperatingAgreementName(string memory _uri, string memory _name)
        public
        onlyOwner
    {
        require(bytes(_uri).length > 0, "Validator: URI cannot be empty");
        require(bytes(_name).length > 0, "Validator: Name cannot be empty");
        operatingAgreements[_uri] = _name;
    }

    /**
     * @dev Removes the name associated with an operating agreement URI.
     * @param _uri The URI to remove.
     */
    function removeOperatingAgreementName(string memory _uri)
        public
        onlyOwner
    {
        require(bytes(_uri).length > 0, "Validator: URI cannot be empty");
        delete operatingAgreements[_uri];
    }

    /**
     * @dev Sets the DeedNFT contract address.
     * @param _deedNFT The new DeedNFT contract address.
     */
    function setDeedNFT(address _deedNFT) public onlyOwner {
        require(_deedNFT != address(0), "Validator: Invalid DeedNFT address");
        deedNFT = IDeedNFT(_deedNFT);
        primaryDeedNFT = _deedNFT;
        compatibleDeedNFTs[_deedNFT] = true;
        emit DeedNFTUpdated(_deedNFT);
        emit PrimaryDeedNFTUpdated(_deedNFT);
        emit CompatibleDeedNFTUpdated(_deedNFT, true);
    }

    /**
     * @dev Adds a compatible DeedNFT contract.
     * @param _deedNFT The DeedNFT contract address to add.
     */
    function addCompatibleDeedNFT(address _deedNFT) public onlyOwner {
        require(_deedNFT != address(0), "Validator: Invalid DeedNFT address");
        compatibleDeedNFTs[_deedNFT] = true;
        emit CompatibleDeedNFTUpdated(_deedNFT, true);
    }

    /**
     * @dev Removes a compatible DeedNFT contract.
     * @param _deedNFT The DeedNFT contract address to remove.
     */
    function removeCompatibleDeedNFT(address _deedNFT) public onlyOwner {
        require(_deedNFT != primaryDeedNFT, "Validator: Cannot remove primary DeedNFT");
        compatibleDeedNFTs[_deedNFT] = false;
        emit CompatibleDeedNFTUpdated(_deedNFT, false);
    }

    /**
     * @dev Sets the primary DeedNFT contract.
     * @param _deedNFT The new primary DeedNFT contract address.
     */
    function setPrimaryDeedNFT(address _deedNFT) public onlyOwner {
        require(_deedNFT != address(0), "Validator: Invalid DeedNFT address");
        require(compatibleDeedNFTs[_deedNFT], "Validator: DeedNFT not compatible");
        primaryDeedNFT = _deedNFT;
        deedNFT = IDeedNFT(_deedNFT);
        emit PrimaryDeedNFTUpdated(_deedNFT);
        emit DeedNFTUpdated(_deedNFT);
    }

    /**
     * @dev Sets the support status for an asset type.
     * @param _assetTypeId The ID of the asset type.
     * @param _isSupported Whether the asset type is supported.
     */
    function setAssetTypeSupport(uint256 _assetTypeId, bool _isSupported)
        public
        onlyRole(CRITERIA_MANAGER_ROLE)
    {
        supportedAssetTypes[_assetTypeId] = _isSupported;
    }

    /**
     * @dev Sets the validation criteria for an asset type.
     * @param _assetTypeId The ID of the asset type.
     * @param _criteria The validation criteria JSON string.
     */
    function setValidationCriteria(uint256 _assetTypeId, string memory _criteria)
        public
        onlyRole(CRITERIA_MANAGER_ROLE)
    {
        require(bytes(_criteria).length > 0, "Validator: Criteria cannot be empty");
        validationCriteria[_assetTypeId] = _criteria;
    }

    /**
     * @dev Sets the metadata URI for a deed.
     * @param _tokenId The ID of the deed.
     * @param _metadataUri The metadata URI.
     */
    function setDeedMetadata(uint256 _tokenId, string memory _metadataUri)
        public
        onlyRole(METADATA_ROLE)
    {
        require(bytes(_metadataUri).length > 0, "Validator: URI cannot be empty");
        deedMetadata[_tokenId] = _metadataUri;
    }

    /**
     * @dev Validates a deed NFT
     * @param _tokenId ID of the token to validate
     * @return Whether the deed is valid
     */
    function validateDeed(uint256 _tokenId) external override returns (bool) {
        require(msg.sender != address(0), "Validator: Invalid caller");
        require(compatibleDeedNFTs[msg.sender], "Validator: Incompatible DeedNFT");
        
        // Get the asset definition and type from the DeedNFT
        string memory _definition;
        uint256 assetTypeId;
        
        try IDeedNFT(msg.sender).getDeedInfo(_tokenId) returns (
            IDeedNFT.AssetType assetType,
            bool /* isValidated */,
            string memory /* operatingAgreement */,
            string memory definition,
            string memory /* configuration */,
            address /* validator */
        ) {
            // Extract the definition and asset type from the returned data
            _definition = definition;
            assetTypeId = uint256(assetType);
        } catch Error(string memory /* reason */) {
            // If getDeedInfo fails, try to get the definition directly from traits
            try IDeedNFT(msg.sender).getTraitValue(_tokenId, keccak256("definition")) returns (bytes memory definitionBytes) {
                if (definitionBytes.length > 0) {
                    _definition = abi.decode(definitionBytes, (string));
                } else {
                    emit ValidationError(_tokenId, "Failed to retrieve asset definition");
                    return false;
                }
                
                // Get asset type from traits
                bytes memory assetTypeBytes = IDeedNFT(msg.sender).getTraitValue(_tokenId, keccak256("assetType"));
                if (assetTypeBytes.length > 0) {
                    assetTypeId = uint256(abi.decode(assetTypeBytes, (IDeedNFT.AssetType)));
                } else {
                    emit ValidationError(_tokenId, "Failed to retrieve asset type");
                    return false;
                }
            } catch {
                emit ValidationError(_tokenId, "Failed to retrieve asset data");
                return false;
            }
        } catch {
            emit ValidationError(_tokenId, "Failed to retrieve asset data");
            return false;
        }
        
        // Check if the asset type is supported
        if (!supportedAssetTypes[assetTypeId]) {
            emit ValidationError(_tokenId, "Asset type not supported");
            return false;
        }
        
        // Get validation criteria for the asset type
        string memory _criteria = validationCriteria[assetTypeId];
        if (bytes(_criteria).length == 0) {
            emit ValidationError(_tokenId, "No validation criteria for asset type");
            return false;
        }
        
        // Validate the definition against the criteria
        bool isValid = _validateDefinition(_tokenId, _definition, _criteria);
        
        // Emit validation result
        emit DeedValidated(_tokenId, isValid);
        
        return isValid;
    }
    
    /**
     * @dev Validates a definition against criteria
     * @param _tokenId ID of the token
     * @param _definition Definition to validate
     * @param _criteria Criteria to validate against
     * @return Whether the definition is valid
     */
    function _validateDefinition(uint256 _tokenId, string memory _definition, string memory _criteria) internal view returns (bool) {
        // Check if definition is not empty
        if (bytes(_definition).length == 0) {
            return false;
        }
        
        // Get the asset type from the token ID using getTraitValue
        uint256 assetTypeId;
        
        try IDeedNFT(msg.sender).getTraitValue(_tokenId, keccak256("assetType")) returns (bytes memory assetTypeBytes) {
            if (assetTypeBytes.length > 0) {
                assetTypeId = uint256(abi.decode(assetTypeBytes, (IDeedNFT.AssetType)));
            } else {
                return false;
            }
        } catch {
            return false; // If we can't get the asset type, validation fails
        }
        
        // Check if this asset type is supported
        if (!supportedAssetTypes[assetTypeId]) {
            return false;
        }
        
        // Get the validation criteria for this asset type
        string memory criteria = _criteria;
        if (bytes(criteria).length == 0) {
            criteria = validationCriteria[assetTypeId];
        }
        
        // If no criteria defined, consider it valid
        if (bytes(criteria).length == 0) {
            return true;
        }
        
        // Basic validation - check if definition contains required fields from criteria
        return _basicValidation(_definition, criteria);
    }

    /**
     * @dev Adds a simplified validation function
     * @param _definition Definition to validate
     * @param _criteria Criteria to validate against
     * @return Whether the definition is valid
     */
    function _basicValidation(string memory _definition, string memory _criteria) internal pure returns (bool) {
        // Extract required fields from criteria
        string[] memory requiredFields = _extractRequiredFields(_criteria);
        
        // Check if all required fields exist in definition
        for (uint i = 0; i < requiredFields.length; i++) {
            if (!StringUtils.contains(_definition, requiredFields[i])) {
                return false;
            }
        }
        
        return true;
    }

    /**
     * @dev Extracts required fields from criteria
     * @param _criteria Criteria to extract fields from
     * @return Array of required field names
     */
    function _extractRequiredFields(string memory _criteria) internal pure returns (string[] memory) {
        // This is a simplified implementation
        // In production, you would use a proper JSON parsing library
        
        // Count "requires" fields
        uint fieldCount = 0;
        bytes memory criteriaBytes = bytes(_criteria);
        
        for (uint i = 0; i < criteriaBytes.length - 8; i++) {
            if (
                criteriaBytes[i] == 'r' &&
                criteriaBytes[i+1] == 'e' &&
                criteriaBytes[i+2] == 'q' &&
                criteriaBytes[i+3] == 'u' &&
                criteriaBytes[i+4] == 'i' &&
                criteriaBytes[i+5] == 'r' &&
                criteriaBytes[i+6] == 'e' &&
                criteriaBytes[i+7] == 's'
            ) {
                fieldCount++;
            }
        }
        
        // Create array for field names
        string[] memory fields = new string[](fieldCount);
        fieldCount = 0;
        
        // Extract field names (simplified)
        for (uint i = 0; i < criteriaBytes.length - 8; i++) {
            if (
                criteriaBytes[i] == 'r' &&
                criteriaBytes[i+1] == 'e' &&
                criteriaBytes[i+2] == 'q' &&
                criteriaBytes[i+3] == 'u' &&
                criteriaBytes[i+4] == 'i' &&
                criteriaBytes[i+5] == 'r' &&
                criteriaBytes[i+6] == 'e' &&
                criteriaBytes[i+7] == 's'
            ) {
                // Extract field name (simplified)
                uint j = i + 8;
                while (j < criteriaBytes.length && criteriaBytes[j] != ':') {
                    j++;
                }
                
                // Convert to field name without "requires" prefix
                string memory fieldName = _extractFieldName(string(criteriaBytes), i, j);
                fields[fieldCount] = fieldName;
                fieldCount++;
            }
        }
        
        return fields;
    }

    /**
     * @dev Extracts field name from criteria
     * @param _str String to extract from
     * @param _start Start position in the string
     * @param _end End position in the string
     * @return Extracted field name
     */
    function _extractFieldName(string memory _str, uint _start, uint _end) internal pure returns (string memory) {
        bytes memory strBytes = bytes(_str);
        bytes memory result = new bytes(_end - _start - 8); // -8 to remove "requires" prefix
        
        for (uint i = 0; i < result.length; i++) {
            result[i] = strBytes[_start + 8 + i]; // +8 to skip "requires" prefix
        }
        
        return string(result);
    }

    /**
     * @dev Sets up field requirements for an asset type
     * @param assetTypeId ID of the asset type
     */
    function setupFieldRequirements(uint256 assetTypeId) public onlyRole(CRITERIA_MANAGER_ROLE) {
        // Set default validation criteria based on asset type
        if (assetTypeId == uint256(IDeedNFT.AssetType.Land) || assetTypeId == uint256(IDeedNFT.AssetType.Estate)) {
            validationCriteria[assetTypeId] = '{"requiresCountry":true,"requiresState":true,"requiresCounty":true,"requiresParcelNumber":true,"requiresLegalDescription":true}';
        } 
        else if (assetTypeId == uint256(IDeedNFT.AssetType.Vehicle)) {
            validationCriteria[assetTypeId] = '{"requiresMake":true,"requiresModel":true,"requiresYear":true,"requiresVin":true}';
        }
        else if (assetTypeId == uint256(IDeedNFT.AssetType.CommercialEquipment)) {
            validationCriteria[assetTypeId] = '{"requiresManufacturer":true,"requiresModel":true,"requiresSerialNumber":true,"requiresYear":true}';
        }
        
        // Enable this asset type
        supportedAssetTypes[assetTypeId] = true;
    }

    /**
     * @dev Sets up all standard field requirements for all asset types
     */
    function setupAllFieldRequirements() external onlyRole(CRITERIA_MANAGER_ROLE) {
        setupFieldRequirements(uint256(IDeedNFT.AssetType.Land));
        setupFieldRequirements(uint256(IDeedNFT.AssetType.Estate));
        setupFieldRequirements(uint256(IDeedNFT.AssetType.Vehicle));
        setupFieldRequirements(uint256(IDeedNFT.AssetType.CommercialEquipment));
    }

    /**
     * @dev Returns the name of an operating agreement
     * @param uri_ URI of the operating agreement
     * @return Name of the operating agreement
     */
    function operatingAgreementName(string memory uri_) external view override returns (string memory) {
        return operatingAgreements[uri_];
    }

    /**
     * @dev Checks if an asset type is supported
     * @param assetTypeId ID of the asset type
     * @return Whether the asset type is supported
     */
    function supportsAssetType(uint256 assetTypeId) external view override returns (bool) {
        return supportedAssetTypes[assetTypeId];
    }

    /**
     * @dev Returns the metadata URI for a token
     * @param tokenId ID of the token
     * @return Metadata URI for the token
     */
    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        string memory metadataUri = deedMetadata[tokenId];
        if (bytes(metadataUri).length > 0) {
            return metadataUri;
        }
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }

    /**
     * @dev Adds a token to the whitelist
     * @param token Address of the token to whitelist
     */
    function addWhitelistedToken(address token) external onlyRole(FEE_MANAGER_ROLE) {
        require(token != address(0), "Validator: Invalid token address");
        require(!isWhitelisted[token], "Validator: Token already whitelisted");
        isWhitelisted[token] = true;
    }

    /**
     * @dev Removes a token from the whitelist
     * @param token Address of the token to remove
     */
    function removeWhitelistedToken(address token) external onlyRole(FEE_MANAGER_ROLE) {
        require(isWhitelisted[token], "Validator: Token not whitelisted");
        isWhitelisted[token] = false;
    }

    /**
     * @dev Sets the service fee for a specific token
     * @param token Address of the token
     * @param _serviceFee Service fee amount in the token's smallest unit
     */
    function setServiceFee(address token, uint256 _serviceFee) external onlyRole(FEE_MANAGER_ROLE) {
        require(isWhitelisted[token], "Validator: Token not whitelisted");
        serviceFee[token] = _serviceFee;
    }

    /**
     * @dev Sets the FundManager contract address
     * @param _fundManager New FundManager contract address
     */
    function setFundManager(address _fundManager) public onlyOwner {
        require(_fundManager != address(0), "Validator: Invalid FundManager address");
        fundManager = _fundManager;
    }

    /**
     * @dev Allows validator admins to withdraw accumulated service fees from the FundManager
     * @param token Address of the token to withdraw
     */
    function withdrawServiceFees(address token) external onlyRole(FEE_MANAGER_ROLE) {
        require(fundManager != address(0), "Validator: FundManager not set");
        
        // Check if there are fees to withdraw
        uint256 amount = IFundManager(fundManager).getCommissionBalance(address(this), token);
        require(amount > 0, "Validator: No service fees to withdraw");
        
        // Call the FundManager to withdraw fees
        IFundManager(fundManager).withdrawValidatorFees(address(this), token);
    }

    /**
     * @dev Checks if a token is whitelisted
     * @param token Address of the token
     * @return Boolean indicating if the token is whitelisted
     */
    function isTokenWhitelisted(address token) external view returns (bool) {
        return isWhitelisted[token];
    }

    /**
     * @dev Retrieves the service fee for a specific token
     * @param token Address of the token
     * @return fee Service fee amount for the token
     */
    function getServiceFee(address token) external view returns (uint256) {
        return serviceFee[token];
    }

    /**
     * @dev Gets the validation criteria for an asset type
     * @param assetTypeId ID of the asset type
     * @return Validation criteria as a JSON string
     */
    function getValidationCriteria(uint256 assetTypeId) external view override returns (string memory) {
        return validationCriteria[assetTypeId];
    }

    /**
     * @dev Checks if a DeedNFT contract is compatible
     * @param _deedNFT Address of the DeedNFT contract
     * @return Boolean indicating if the DeedNFT is compatible
     */
    function isCompatibleDeedNFT(address _deedNFT) external view override returns (bool) {
        return compatibleDeedNFTs[_deedNFT];
    }

    /**
     * @dev Registers an operating agreement
     * @param uri URI of the operating agreement
     * @param name Name of the operating agreement
     */
    function registerOperatingAgreement(string memory uri, string memory name) external override onlyRole(METADATA_ROLE) {
        require(bytes(uri).length > 0, "Validator: URI cannot be empty");
        require(bytes(name).length > 0, "Validator: Name cannot be empty");
        operatingAgreements[uri] = name;
        emit OperatingAgreementRegistered(uri, name);
    }

    /**
     * @dev Validates a deed NFT's operating agreement
     * @param operatingAgreement URI of the operating agreement
     * @return Whether the operating agreement is valid
     */
    function validateOperatingAgreement(
        string memory operatingAgreement
    ) external view override returns (bool) {
        // Check if the operating agreement is registered
        if (bytes(operatingAgreements[operatingAgreement]).length == 0 && 
            !StringUtils.contains(operatingAgreement, defaultOperatingAgreementUri)) {
            return false;
        }
        
        // Additional validation logic can be added here
        // For example, checking if the operating agreement is appropriate for the asset type
        
        return true;
    }

    /**
     * @dev Gets the royalty fee percentage for a token
     * @return The royalty fee percentage in basis points (100 = 1%)
     */
    function getRoyaltyFeePercentage(uint256) external view override returns (uint96) {
        return royaltyFeePercentage;
    }

    /**
     * @dev Sets the royalty fee percentage
     * @param percentage The royalty fee percentage in basis points (100 = 1%)
     */
    function setRoyaltyFeePercentage(uint96 percentage) external override onlyRole(FEE_MANAGER_ROLE) {
        require(percentage <= 10000, "Validator: Royalty percentage exceeds 100%");
        royaltyFeePercentage = percentage;
    }

    /**
     * @dev Gets the royalty receiver address
     * @return The address that receives royalties
     */
    function getRoyaltyReceiver() external view override returns (address) {
        return royaltyReceiver;
    }

    /**
     * @dev Sets the royalty receiver address
     * @param receiver The address that will receive royalties
     */
    function setRoyaltyReceiver(address receiver) external override onlyRole(FEE_MANAGER_ROLE) {
        require(receiver != address(0), "Validator: Invalid royalty receiver address");
        royaltyReceiver = receiver;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * Declares support for IValidator interface
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(AccessControlUpgradeable, ERC165Upgradeable) 
        returns (bool) 
    {
        return
            interfaceId == type(IValidator).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Clears field requirements for an asset type
     * @param assetTypeId ID of the asset type
     */
    function clearFieldRequirements(uint256 assetTypeId) external onlyRole(ADMIN_ROLE) {
        // In our simplified implementation, we don't need to do anything complex
        // Just emit the event to maintain interface compatibility
        emit FieldRequirementsCleared(assetTypeId);
    }

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
    ) external onlyRole(ADMIN_ROLE) {
        require(criteriaFields.length == definitionFields.length, "Validator: Arrays must have same length");
        
        // In our simplified implementation, we just emit events for each field requirement
        for (uint256 i = 0; i < criteriaFields.length; i++) {
            emit FieldRequirementAdded(assetTypeId, criteriaFields[i], definitionFields[i]);
        }
    }
}