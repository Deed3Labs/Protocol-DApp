// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

// OpenZeppelin Upgradeable Contracts
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

// External validator and registry interfaces
import "./interfaces/IValidator.sol";
import "./interfaces/IValidatorRegistry.sol";
import "./interfaces/IERC7572.sol";

// Import ICreatorToken interface for reference
import "@limitbreak/creator-token-standards/src/interfaces/ICreatorToken.sol";
import "@limitbreak/creator-token-standards/src/erc721c/ERC721C.sol";

/**
 * @title DeedNFT
 * @dev An ERC-721 token representing deeds with complex metadata and validator integration.
 *      Implements ERC-7496 for dynamic traits and ERC-7572 for metadata rendering.
 *      Implements royalty enforcement inspired by ERC721-C.
 */
contract DeedNFT is
    Initializable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    ICreatorToken,
    IERC2981Upgradeable
{
    using StringsUpgradeable for uint256;
    using AddressUpgradeable for address;

    // ============ Role Definitions ============
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // ============ Asset Types ============
    enum AssetType {
        Land,
        Vehicle,
        Estate,
        CommercialEquipment
    }

    // ============ State Variables ============
    uint256 public nexttokenId;
    address private defaultValidator;
    address private validatorRegistry;
    string private _contractURI;
    address public metadataRenderer;

    // ============ ERC721-C Security Policy ============
    // Mapping to track approved marketplaces
    mapping(address => bool) private _approvedMarketplaces;
    bool private _enforceRoyalties;
    address private _transferValidator;

    // ============ ERC-7496 Trait Storage ============
    /**
     * @dev Mapping from token ID to trait key to trait value
     * @notice Implements ERC-7496 trait storage
     */
    mapping(uint256 => mapping(bytes32 => bytes)) private _tokenTraits;
    
    /**
     * @dev Mapping from trait key to trait name
     * @notice Used for ERC-7496 trait metadata
     */
    mapping(bytes32 => string) private _traitNames;
    
    /**
     * @dev Array of all possible trait keys
     * @notice Used for ERC-7496 trait enumeration
     */
    bytes32[] private _allTraitKeys;

    // ============ Events ============
    event DeedNFTMinted(
        uint256 indexed tokenId,
        AssetType assetType,
        address indexed minter,
        address validator
    );
    event DeedNFTBurned(uint256 indexed tokenId);
    event DeedNFTValidatedChanged(uint256 indexed tokenId, bool isValid);
    event DeedNFTMetadataUpdated(uint256 indexed tokenId);
    event MetadataRendererUpdated(address indexed renderer);
    event ContractURIUpdated(string newURI);
    event TraitUpdated(bytes32 indexed traitKey, uint256 indexed tokenId, bytes traitValue);
    event TraitMetadataURIUpdated();
    event TokenValidated(uint256 indexed tokenId, bool isValid, address validator);
    event MarketplaceApproved(address indexed marketplace, bool approved);
    event RoyaltyEnforcementChanged(bool enforced);

    // Storage gap for future upgrades
    uint256[45] private __gap;

    /**
     * @dev Count of active tokens (more efficient than iterating)
     */
    uint256 private _activeTokenCount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract with default validator and registry addresses.
     * @param _defaultValidator Address of the default validator contract.
     * @param _validatorRegistry Address of the validator registry contract.
     */
    function initialize(
        address _defaultValidator,
        address _validatorRegistry
    ) public initializer {
        __ERC721_init("DeedNFT", "DEED");
        __ERC721URIStorage_init();
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VALIDATOR_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        defaultValidator = _defaultValidator;
        validatorRegistry = _validatorRegistry;
        nexttokenId = 1;
        _activeTokenCount = 0;
        
        // Initialize trait keys and names
        _initializeTraits();
        
        // Set default security policy
        setToDefaultSecurityPolicy();
    }
    
    /**
     * @dev Initialize trait keys and names
     */
    function _initializeTraits() private {
        // Define trait keys
        bytes32 assetTypeKey = keccak256("assetType");
        bytes32 isValidatedKey = keccak256("isValidated");
        bytes32 operatingAgreementKey = keccak256("operatingAgreement");
        bytes32 definitionKey = keccak256("definition");
        bytes32 configurationKey = keccak256("configuration");
        bytes32 validatorKey = keccak256("validator");
        
        // Store trait keys
        _allTraitKeys = [
            assetTypeKey,
            isValidatedKey,
            operatingAgreementKey,
            definitionKey,
            configurationKey,
            validatorKey
        ];
        
        // Map trait keys to names
        _traitNames[assetTypeKey] = "Asset Type";
        _traitNames[isValidatedKey] = "Validation Status";
        _traitNames[operatingAgreementKey] = "Operating Agreement";
        _traitNames[definitionKey] = "Definition";
        _traitNames[configurationKey] = "Configuration";
        _traitNames[validatorKey] = "Validator";
        
        emit TraitMetadataURIUpdated();
    }

    /**
     * @dev Authorizes the contract upgrade. Only accounts with DEFAULT_ADMIN_ROLE can upgrade.
     * @param newImplementation Address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        // Authorization logic handled by onlyRole modifier
    }

    // Modifiers

    /**
     * @dev Modifier to check if the deed exists
     */
    modifier deedExists(uint256 tokenId) {
        require(_exists(tokenId), "No deed");
        _;
    }

    /**
     * @dev Modifier to check if the caller is the deed owner
     */
    modifier onlyDeedOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        _;
    }

    /**
     * @dev Modifier to check if the caller is a validator or the deed owner
     */
    modifier onlyValidatorOrOwner(uint256 tokenId) {
        require(
            hasRole(VALIDATOR_ROLE, msg.sender) || ownerOf(tokenId) == msg.sender,
            "Not authorized"
        );
        _;
    }

    function _exists(uint256 tokenId) internal view override returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    // Pausable functions

    /**
     * @dev Pauses all contract operations.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
        emit Paused(msg.sender);
    }

    /**
     * @dev Unpauses all contract operations.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
        emit Unpaused(msg.sender);
    }

    // Validator functions

    /**
     * @dev Sets the default validator address.
     * @param validator Address of the new default validator.
     */
    function setDefaultValidator(address validator)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(validator != address(0), "Invalid validator");
        require(
            IValidatorRegistry(validatorRegistry).isValidatorRegistered(
                validator
            ),
            "Not registered"
        );
        defaultValidator = validator;
    }

    /**
     * @dev Sets the validator registry address.
     * @param registry Address of the validator registry.
     */
    function setValidatorRegistry(address registry)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(registry != address(0), "Invalid registry");
        validatorRegistry = registry;
    }
    
    /**
     * @dev Sets the metadata renderer address (ERC-7572).
     * @param renderer Address of the metadata renderer.
     */
    function setMetadataRenderer(address renderer)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(renderer != address(0), "Invalid renderer");
        metadataRenderer = renderer;
        emit MetadataRendererUpdated(renderer);
    }

    /**
     * @dev Grants the MINTER_ROLE to an address.
     *      Only callable by accounts with DEFAULT_ADMIN_ROLE.
     * @param minter Address to grant the MINTER_ROLE to.
     */
    function addMinter(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minter != address(0), "Invalid minter");
        _grantRole(MINTER_ROLE, minter);
    }

    /**
     * @dev Revokes the MINTER_ROLE from an address.
     *      Only callable by accounts with DEFAULT_ADMIN_ROLE.
     * @param minter Address to revoke the MINTER_ROLE from.
     */
    function removeMinter(address minter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
    }

    /**
     * @dev Generates a unique token ID based on input parameters
     */
    function generateUniqueTokenId(
        address owner,
        AssetType assetType,
        string memory definition,
        uint256 salt
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            owner,
            uint8(assetType),
            definition,
            salt
        ))) % 1000000000; // Keep it to 9 digits for readability
    }

    /**
     * @dev Mints a new deed with a deterministic token ID
     */
    function mintAsset(
        address owner,
        AssetType assetType,
        string memory ipfsDetailsHash,
        string memory definition,
        string memory configuration,
        address validatorAddress,
        uint256 salt
    ) external whenNotPaused onlyRole(MINTER_ROLE) returns (uint256) {
        require(owner != address(0), "Invalid owner");
        require(
            bytes(ipfsDetailsHash).length > 0,
            "IPFS hash required"
        );
        require(
            bytes(definition).length > 0,
            "Definition required"
        );

        // Determine which validator to use
        address selectedValidator = validatorAddress;
        if (selectedValidator == address(0)) {
            selectedValidator = defaultValidator;
        }
        
        // Ensure validator is registered
        require(
            selectedValidator != address(0),
            "No validator"
        );
        require(
            IValidatorRegistry(validatorRegistry).isValidatorRegistered(selectedValidator),
            "Not registered"
        );
        
        // Verify validator supports interface
        require(
            IERC165Upgradeable(selectedValidator).supportsInterface(
                type(IValidator).interfaceId
            ),
            "Invalid interface"
        );
        
        // Verify validator supports this asset type
        require(
            IValidator(selectedValidator).supportsAssetType(uint256(assetType)),
            "Unsupported asset"
        );
        
        // Get default operating agreement from validator
        string memory operatingAgreement = IValidator(selectedValidator).defaultOperatingAgreement();
        require(
            bytes(operatingAgreement).length > 0,
            "No agreement"
        );

        uint256 tokenId;
        
        // Use unique ID generation if salt is provided, otherwise use sequential ID
        if (salt > 0) {
            tokenId = generateUniqueTokenId(owner, assetType, definition, salt);
            // Ensure the token ID doesn't already exist
            require(!_exists(tokenId), "Token ID already exists");
        } else {
            // Use the sequential ID approach
            tokenId = nexttokenId;
            nexttokenId++;
        }
        
        _mint(owner, tokenId);
        _setTokenURI(tokenId, ipfsDetailsHash);

        // Set traits using ERC-7496
        _setTraitValue(tokenId, keccak256("assetType"), abi.encode(assetType));
        _setTraitValue(tokenId, keccak256("isValidated"), abi.encode(false));
        _setTraitValue(tokenId, keccak256("operatingAgreement"), abi.encode(operatingAgreement));
        _setTraitValue(tokenId, keccak256("definition"), abi.encode(definition));
        _setTraitValue(tokenId, keccak256("configuration"), abi.encode(configuration));
        _setTraitValue(tokenId, keccak256("validator"), abi.encode(address(0)));

        emit DeedNFTMinted(tokenId, assetType, msg.sender, selectedValidator);
        return tokenId;
    }

    // Burning functions

    /**
     * @dev Burns a deed owned by the caller.
     * @param tokenId ID of the deed to burn.
     */
    function burnAsset(uint256 tokenId)
        public
        onlyDeedOwner(tokenId)
        whenNotPaused
    {
        _burn(tokenId);
        
        // Clear all traits
        for (uint i = 0; i < _allTraitKeys.length; i++) {
            delete _tokenTraits[tokenId][_allTraitKeys[i]];
        }
        
        emit DeedNFTBurned(tokenId);
    }

    /**
     * @dev Batch burns multiple deeds owned by the caller.
     * @param tokenIds Array of deed IDs to burn.
     */
    function burnBatchAssets(uint256[] memory tokenIds)
        external
        whenNotPaused
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(
                ownerOf(tokenId) == msg.sender,
                "Not owner"
            );
            burnAsset(tokenId);
        }
    }

    // Validation functions

    /**
     * @dev Updates the validation status of a token
     * @param tokenId ID of the token to validate
     * @param isValid Whether the token is valid
     * @param validatorAddress Address of the validator
     */
    function validateDeed(uint256 tokenId, bool isValid, address validatorAddress) 
        external 
        onlyRole(VALIDATOR_ROLE) 
    {
        require(_exists(tokenId), "No deed");
        
        // If marking as valid, ensure validator address is provided and valid
        if (isValid) {
            require(validatorAddress != address(0), "No validator");
            require(
                IValidatorRegistry(validatorRegistry).isValidatorRegistered(validatorAddress),
                "Not registered"
            );
            
            require(
                IERC165Upgradeable(validatorAddress).supportsInterface(
                    type(IValidator).interfaceId
                ),
                "Invalid interface"
            );
            
            bytes memory agrBytes = _tokenTraits[tokenId][keccak256("operatingAgreement")];
            require(
                IValidator(validatorAddress).validateOperatingAgreement(abi.decode(agrBytes, (string))),
                "Invalid agreement"
            );
            
            // Update traits
            _setTraitValue(tokenId, keccak256("isValidated"), abi.encode(true));
            _setTraitValue(tokenId, keccak256("validator"), abi.encode(validatorAddress));
        } else {
            // If invalidating, reset validation status
            _setTraitValue(tokenId, keccak256("isValidated"), abi.encode(false));
            _setTraitValue(tokenId, keccak256("validator"), abi.encode(address(0)));
        }
        
        emit TokenValidated(tokenId, isValid, validatorAddress);
    }

    // Metadata functions

    /**
     * @dev Updates the metadata of a deed.
     *      Only callable by the owner or a validator.
     *      If called by a non-validator, sets isValidated to false.
     * @param tokenId ID of the deed.
     * @param ipfsDetailsHash New IPFS details hash.
     * @param operatingAgreement New operating agreement.
     * @param definition New definition.
     * @param configuration New configuration.
     */
    function updateMetadata(
        uint256 tokenId,
        string memory ipfsDetailsHash,
        string memory operatingAgreement,
        string memory definition,
        string memory configuration
    ) external onlyValidatorOrOwner(tokenId) whenNotPaused {
        require(
            bytes(ipfsDetailsHash).length > 0,
            "IPFS hash required"
        );
        require(
            bytes(operatingAgreement).length > 0,
            "Agreement required"
        );
        require(
            bytes(definition).length > 0,
            "Definition required"
        );

        // Check if operating agreement is valid
        bytes memory validatorBytes = _tokenTraits[tokenId][keccak256("validator")];
        address validatorAddress = validatorBytes.length > 0 
            ? abi.decode(validatorBytes, (address)) 
            : defaultValidator;

        require(
            validatorAddress != address(0),
            "No validator"
        );
        require(
            IERC165Upgradeable(validatorAddress).supportsInterface(
                type(IValidator).interfaceId
            ),
            "Invalid interface"
        );

        string memory agreementName = IValidator(validatorAddress)
            .operatingAgreementName(operatingAgreement);
        require(
            bytes(agreementName).length > 0,
            "Invalid agreement"
        );

        _setTokenURI(tokenId, ipfsDetailsHash);

        // Update traits
        _setTraitValue(tokenId, keccak256("operatingAgreement"), abi.encode(operatingAgreement));
        _setTraitValue(tokenId, keccak256("definition"), abi.encode(definition));
        _setTraitValue(tokenId, keccak256("configuration"), abi.encode(configuration));
        
        // If not called by validator, reset validation status
        if (!hasRole(VALIDATOR_ROLE, msg.sender)) {
            _setTraitValue(tokenId, keccak256("isValidated"), abi.encode(false));
            _setTraitValue(tokenId, keccak256("validator"), abi.encode(address(0)));
        }

        emit DeedNFTMetadataUpdated(tokenId);
    }
    
    // ERC-7496 Implementation
    
    /**
     * @dev Sets a trait value for a token
     * @param tokenId ID of the token
     * @param traitKey Key of the trait
     * @param traitValue Value of the trait
     * @notice Updates a trait and emits a TraitUpdated event
     */
    function _setTraitValue(uint256 tokenId, bytes32 traitKey, bytes memory traitValue) internal {
        require(_exists(tokenId), "Token not found");
        _tokenTraits[tokenId][traitKey] = traitValue;
        emit TraitUpdated(traitKey, tokenId, traitValue);
    }
    
    /**
     * @dev Gets a trait value for a token
     * @param tokenId ID of the token
     * @param traitKey Key of the trait
     * @return Value of the trait
     * @notice Part of the ERC-7496 standard for dynamic traits
     */
    function getTraitValue(uint256 tokenId, bytes32 traitKey) external view returns (bytes memory) {
        require(_exists(tokenId), "Token not found");
        return _tokenTraits[tokenId][traitKey];
    }
    
    /**
     * @dev Gets multiple trait values for a token
     * @param tokenId ID of the token
     * @param traitKeys Array of trait keys
     * @return Array of trait values
     * @notice Part of the ERC-7496 standard for dynamic traits
     */
    function getTraitValues(uint256 tokenId, bytes32[] calldata traitKeys) external view returns (bytes[] memory) {
        require(_exists(tokenId), "Token does not exist");
        bytes[] memory values = new bytes[](traitKeys.length);
        
        for (uint256 i = 0; i < traitKeys.length; i++) {
            values[i] = _tokenTraits[tokenId][traitKeys[i]];
        }
        
        return values;
    }
    
    /**
     * @dev Gets all trait keys for a token that have values
     * @param tokenId ID of the token
     * @return Array of trait keys that have values
     * @notice Part of the ERC-7496 standard for dynamic traits
     */
    function getTraitKeys(uint256 tokenId) external view returns (bytes32[] memory) {
        require(_exists(tokenId), "No token");
        
        // Count traits with values
        uint256 count;
        for (uint i = 0; i < _allTraitKeys.length; i++) {
            if (_tokenTraits[tokenId][_allTraitKeys[i]].length > 0) count++;
        }
        
        bytes32[] memory traitKeys = new bytes32[](count);
        if (count == 0) return traitKeys;
        
        // Fill array
        count = 0;
        for (uint i = 0; i < _allTraitKeys.length; i++) {
            if (_tokenTraits[tokenId][_allTraitKeys[i]].length > 0) {
                traitKeys[count++] = _allTraitKeys[i];
            }
        }
        
        return traitKeys;
    }
    
    /**
     * @dev Gets the name of a trait
     * @param traitKey Key of the trait
     * @return Name of the trait
     * @notice Part of the ERC-7496 standard for dynamic traits
     */
    function getTraitName(bytes32 traitKey) external view returns (string memory) {
        return _traitNames[traitKey];
    }
    
    /**
     * @dev Gets the metadata URI for traits
     * @return Base64-encoded JSON schema of all traits
     * @notice Part of the ERC-7496 standard for dynamic traits
     * @notice The returned JSON schema defines the structure and validation rules for each trait
     */
    function getTraitMetadataURI() external pure returns (string memory) {
        return "data:application/json;charset=utf-8;base64,ewogICJ0cmFpdHMiOiB7CiAgICAiYXNzZXRUeXBlIjogewogICAgICAiZGlzcGxheU5hbWUiOiAiQXNzZXQgVHlwZSIsCiAgICAgICJkYXRhVHlwZSI6IHsKICAgICAgICAidHlwZSI6ICJlbnVtIiwKICAgICAgICAidmFsdWVzIjogWyJMYW5kIiwgIlZlaGljbGUiLCAiRXN0YXRlIiwgIkNvbW1lcmNpYWxFcXVpcG1lbnQiXQogICAgICB9CiAgICB9LAogICAgImlzVmFsaWRhdGVkIjogewogICAgICAiZGlzcGxheU5hbWUiOiAiVmFsaWRhdGlvbiBTdGF0dXMiLAogICAgICAiZGF0YVR5cGUiOiB7CiAgICAgICAgInR5cGUiOiAiYm9vbGVhbiIKICAgICAgfQogICAgfSwKICAgICJvcGVyYXRpbmdBZ3JlZW1lbnQiOiB7CiAgICAgICJkaXNwbGF5TmFtZSI6ICJPcGVyYXRpbmcgQWdyZWVtZW50IiwKICAgICAgImRhdGFUeXBlIjogewogICAgICAgICJ0eXBlIjogInN0cmluZyIsCiAgICAgICAgIm1pbkxlbmd0aCI6IDEKICAgICAgfQogICAgfSwKICAgICJkZWZpbml0aW9uIjogewogICAgICAiZGlzcGxheU5hbWUiOiAiRGVmaW5pdGlvbiIsCiAgICAgICJkYXRhVHlwZSI6IHsKICAgICAgICAidHlwZSI6ICJzdHJpbmciLAogICAgICAgICJtaW5MZW5ndGgiOiAxCiAgICAgIH0KICAgIH0sCiAgICAiY29uZmlndXJhdGlvbiI6IHsKICAgICAgImRpc3BsYXlOYW1lIjogIkNvbmZpZ3VyYXRpb24iLAogICAgICAiZGF0YVR5cGUiOiB7CiAgICAgICAgInR5cGUiOiAic3RyaW5nIiwKICAgICAgICAibWluTGVuZ3RoIjogMQogICAgICB9CiAgICB9LAogICAgInZhbGlkYXRvciI6IHsKICAgICAgImRpc3BsYXlOYW1lIjogIlZhbGlkYXRvciIsCiAgICAgICJkYXRhVHlwZSI6IHsKICAgICAgICAidHlwZSI6ICJhZGRyZXNzIgogICAgICB9CiAgICB9CiAgfQp9";
    }
    
    // ERC-7572 Implementation
    
    /**
     * @dev Implements ERC-7572: Contract-level metadata
     * @return URI for the contract metadata
     * @notice This function allows marketplaces and wallets to display collection information
     */
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }
    
    /**
     * @dev Sets the contract URI for collection metadata (ERC-7572)
     * @param newURI New contract URI
     * @notice Only callable by admin
     */
    function setContractURI(string memory newURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _contractURI = newURI;
        emit ContractURIUpdated(newURI);
    }
    
    /**
     * @dev Sets a specific token URI for a given token ID.
     * @param tokenId uint256 ID of the token to set its URI
     * @param _tokenURI string URI to assign
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual override {
        require(_exists(tokenId), "URI for nonexistent token");
        super._setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable) 
        returns (string memory) 
    {
        // If we have a metadata renderer, use it
        if (metadataRenderer != address(0)) {
            try IERC7572(metadataRenderer).tokenURI(address(this), tokenId) returns (string memory renderedURI) {
                return renderedURI;
            } catch {
                // Fall back to standard URI if renderer fails
            }
        }
        
        return ERC721URIStorageUpgradeable.tokenURI(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * @param interfaceId Interface identifier
     * @return True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable, AccessControlUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return 
            interfaceId == type(IERC2981Upgradeable).interfaceId ||
            interfaceId == type(ICreatorToken).interfaceId ||
            interfaceId == 0xaf332f3e || // ERC-7496 (Dynamic Traits)
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the validation status of a token
     * @param tokenId ID of the token
     * @return isValidated Whether the token is validated
     * @return validator Address of the validator that validated the token
     */
    function getValidationStatus(uint256 tokenId) 
        external 
        view 
        returns (bool isValidated, address validator) 
    {
        require(_exists(tokenId), "Nonexistent deed");
        
        bytes memory isValidatedBytes = _tokenTraits[tokenId][keccak256("isValidated")];
        bytes memory validatorBytes = _tokenTraits[tokenId][keccak256("validator")];
        
        isValidated = isValidatedBytes.length > 0 ? abi.decode(isValidatedBytes, (bool)) : false;
        validator = validatorBytes.length > 0 ? abi.decode(validatorBytes, (address)) : address(0);
        
        return (isValidated, validator);
    }

    /**
     * @dev Returns the royalty information for a token
     * @param tokenId ID of the token
     * @param salePrice Sale price of the token
     * @return receiver Address that should receive royalties
     * @return royaltyAmount Amount of royalties to be paid
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) 
        external 
        view 
        override 
        returns (address receiver, uint256 royaltyAmount) 
    {
        require(_exists(tokenId), "No token");
        
        bytes memory validatorBytes = _tokenTraits[tokenId][keccak256("validator")];
        address validator = validatorBytes.length > 0 
            ? abi.decode(validatorBytes, (address)) 
            : defaultValidator;
        
        if (validator == address(0)) return (address(0), 0);
        
        uint96 fee = IValidator(validator).getRoyaltyFeePercentage(tokenId);
        receiver = IValidator(validator).getRoyaltyReceiver();
        royaltyAmount = (salePrice * fee) / 10000;
    }

    /**
     * @dev Sets the contract to the default security policy for royalty enforcement
     */
    function setToDefaultSecurityPolicy() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _enforceRoyalties = true;
        emit RoyaltyEnforcementChanged(true);
    }

    /**
     * @dev Approves a marketplace for trading
     * @param marketplace Address of the marketplace
     * @param approved Whether the marketplace is approved
     */
    function setApprovedMarketplace(address marketplace, bool approved) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _approvedMarketplaces[marketplace] = approved;
        emit MarketplaceApproved(marketplace, approved);
    }

    /**
     * @dev Checks if a marketplace is approved
     * @param marketplace Address of the marketplace
     * @return Whether the marketplace is approved
     */
    function isApprovedMarketplace(address marketplace) public view returns (bool) {
        return _approvedMarketplaces[marketplace];
    }

    /**
     * @dev Sets whether royalties are enforced
     * @param enforced Whether royalties are enforced
     */
    function setRoyaltyEnforcement(bool enforced) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _enforceRoyalties = enforced;
        emit RoyaltyEnforcementChanged(enforced);
    }

    /**
     * @dev Checks if royalties are enforced
     * @return Whether royalties are enforced
     */
    function isRoyaltyEnforced() public view returns (bool) {
        return _enforceRoyalties;
    }

    /**
     * @dev Override for approval to enforce royalties
     * @param to Address to approve
     * @param tokenId ID of the token to approve
     */
    function approve(address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721Upgradeable) {
        if (_enforceRoyalties && !isApprovedMarketplace(to)) {
            revert("Unapproved marketplace");
        }
        super.approve(to, tokenId);
    }

    /**
     * @dev Override for setApprovalForAll to enforce royalties
     * @param operator Address to approve
     * @param approved Whether the operator is approved
     */
    function setApprovalForAll(address operator, bool approved) public override(ERC721Upgradeable, IERC721Upgradeable) {
        if (_enforceRoyalties && approved && !isApprovedMarketplace(operator)) {
            revert("Unapproved marketplace");
        }
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Burns a token
     * @param tokenId ID of the token to burn
     */
    function _burn(uint256 tokenId) internal virtual override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /**
     * @dev Gets the transfer validator address
     * @return validator The address of the transfer validator
     */
    function getTransferValidator() external view returns (address validator) {
        return _transferValidator;
    }

    /**
     * @dev Sets the transfer validator address
     * @param validator The address of the transfer validator
     */
    function setTransferValidator(address validator) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address oldValidator = _transferValidator;
        _transferValidator = validator;
        emit TransferValidatorUpdated(oldValidator, validator);
    }

    /**
     * @dev Returns the function selector for the transfer validator's validation function
     * @return functionSignature The function signature
     * @return isViewFunction Whether the function is a view function
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /**
     * @dev Hook that is called before any token transfer. Implements ERC721C compatibility.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        if (batchSize == 0) return;
        
        // Minting
        if (from == address(0)) _activeTokenCount++;
        // Burning
        else if (to == address(0)) _activeTokenCount--;
        // Regular transfer with royalty enforcement
        else if (_enforceRoyalties) {
            address op = _msgSender();
            if (op != from && !_approvedMarketplaces[op]) revert("Not approved");
        }
    }

    /**
     * @dev Returns the total supply of tokens (accounts for burned tokens)
     * @return The total number of active tokens
     */
    function totalSupply() public view returns (uint256) {
        return _activeTokenCount;
    }
}