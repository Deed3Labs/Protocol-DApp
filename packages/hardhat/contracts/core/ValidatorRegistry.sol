// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

// OpenZeppelin Upgradeable Contracts
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Interfaces
import "./interfaces/IValidatorRegistry.sol";
import "./interfaces/IValidator.sol";

/**
 * @title ValidatorRegistry
 * @dev Registry contract for managing validator contracts and their capabilities.
 *      Enables dynamic validator management and asset type validation.
 *      
 * Security:
 * - Role-based access control for registry management
 * - Validator capability verification
 * - Interface compliance checks
 * 
 * Integration:
 * - Works with DeedNFT for asset validation
 * - Manages Validator contract registration
 * - Implements UUPSUpgradeable for upgradability
 */
contract ValidatorRegistry is
    Initializable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    // ============ Role Definitions ============

    /// @notice Role for registry management operations
    /// @dev Has authority to add/remove validators and update their capabilities
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");

    // ============ Data Structures ============

    /**
     * @title ValidatorInfo
     * @dev Information about a registered validator
     * 
     * @param isActive Current operational status
     * @param supportedAssetTypes List of asset types this validator can handle
     * @param name Human-readable name of the validator
     * @param description Detailed description of validator capabilities
     */
    struct ValidatorInfo {
        bool isActive;
        uint256[] supportedAssetTypes;
        string name;
        string description;
    }

    // ============ State Variables ============

    /// @notice Mapping of validator addresses to their information
    /// @dev Key: validator address, Value: ValidatorInfo struct
    mapping(address => ValidatorInfo) public validators;

    /// @notice Mapping of asset types to their approved validators
    /// @dev Key: asset type ID, Value: array of validator addresses
    mapping(uint256 => address[]) public assetTypeValidators;

    // ============ Events ============

    /**
     * @dev Emitted when a new validator is registered
     * @param validator Address of the registered validator
     * @param name Name of the validator
     * @param supportedAssetTypes Array of supported asset type IDs
     */
    event ValidatorRegistered(
        address indexed validator,
        string name,
        uint256[] supportedAssetTypes
    );

    /**
     * @dev Emitted when a validator's status is updated
     * @param validator Address of the affected validator
     * @param isActive New operational status
     */
    event ValidatorStatusUpdated(address indexed validator, bool isActive);

    /**
     * @dev Emitted when a validator's supported asset types are updated
     * @param validator Address of the affected validator
     * @param assetTypes Updated array of supported asset type IDs
     */
    event ValidatorAssetTypesUpdated(
        address indexed validator,
        uint256[] assetTypes
    );

    // ============ Upgrade Gap ============

    /// @dev Storage gap for future upgrades
    uint256[50] private __gap;

    // ============ Constructor ============

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ============ Initializer ============

    /**
     * @dev Initializes the ValidatorRegistry contract
     */
    function initialize() public initializer {
        __AccessControl_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REGISTRY_ADMIN_ROLE, msg.sender);
        _transferOwnership(msg.sender);
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

    /**
     * @dev Registers a new validator.
     * @param validator Address of the validator contract.
     * @param name Name associated with the validator.
     */
    function registerValidator(address validator, string memory name)
        public
        onlyOwner
    {
        require(
            validator != address(0),
            "ValidatorRegistry: Invalid validator address"
        );
        require(
            bytes(name).length > 0,
            "ValidatorRegistry: Name cannot be empty"
        );
        require(
            bytes(validators[validator].name).length == 0,
            "ValidatorRegistry: Validator already registered"
        );

        validators[validator].name = name;
        emit ValidatorRegistered(validator, name, validators[validator].supportedAssetTypes);
    }

    /**
     * @dev Removes a validator from the registry.
     * @param validator Address of the validator contract.
     */
    function removeValidator(address validator) public onlyOwner {
        require(
            bytes(validators[validator].name).length > 0,
            "ValidatorRegistry: Validator not registered"
        );

        delete validators[validator];
        emit ValidatorRegistered(validator, "", new uint256[](0));
    }

    /**
     * @dev Updates the name of a registered validator.
     * @param validator Address of the validator contract.
     * @param newName New name to associate with the validator.
     */
    function updateValidatorName(address validator, string memory newName)
        public
        onlyOwner
    {
        require(
            bytes(validators[validator].name).length > 0,
            "ValidatorRegistry: Validator not registered"
        );
        require(
            bytes(newName).length > 0,
            "ValidatorRegistry: Name cannot be empty"
        );

        validators[validator].name = newName;
        emit ValidatorRegistered(validator, newName, validators[validator].supportedAssetTypes);
    }

    /**
     * @dev Returns the name associated with a validator address.
     * @param validator Address of the validator.
     * @return Name string.
     */
    function getValidatorName(address validator)
        external
        view
        returns (string memory)
    {
        return validators[validator].name;
    }

    /**
     * @dev Checks if a validator is registered.
     * @param validator Address of the validator.
     * @return True if registered, false otherwise.
     */
    function isValidatorRegistered(address validator)
        external
        view
        returns (bool)
    {
        return bytes(validators[validator].name).length > 0;
    }

    /**
     * @dev Updates the supported asset types for a registered validator.
     * @param validator Address of the validator contract.
     * @param assetTypes Array of asset type IDs to be supported by the validator.
     */
    function updateValidatorAssetTypes(address validator, uint256[] memory assetTypes)
        public
        onlyOwner
    {
        require(
            bytes(validators[validator].name).length > 0,
            "ValidatorRegistry: Validator not registered"
        );
        require(
            assetTypes.length > 0,
            "ValidatorRegistry: Asset types array cannot be empty"
        );

        validators[validator].supportedAssetTypes = assetTypes;
        emit ValidatorAssetTypesUpdated(validator, assetTypes);
    }

    /**
     * @dev Updates the operational status of a registered validator.
     * @param validator Address of the validator contract.
     * @param isActive New operational status.
     */
    function updateValidatorStatus(address validator, bool isActive)
        public
        onlyOwner
    {
        require(
            bytes(validators[validator].name).length > 0,
            "ValidatorRegistry: Validator not registered"
        );

        validators[validator].isActive = isActive;
        emit ValidatorStatusUpdated(validator, isActive);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     * Adds support for the IValidatorRegistry interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IValidatorRegistry).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
