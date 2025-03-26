// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

/**
 * @title IValidatorRegistry
 * @dev Interface for the ValidatorRegistry contract.
 *      Defines required functionality for validator management and lookup.
 *      
 * Integration:
 * - Used by DeedNFT for validator verification
 * - Used by FundManager for validator ownership checks
 * - Supports validator registration and capability management
 */
interface IValidatorRegistry {
    // ============ Structs ============

    /**
     * @dev Information about a registered validator
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

    // ============ View Functions ============

    /**
     * @dev Returns the owner of a validator contract
     * @param validatorContract Address of the validator contract
     * @return owner Address of the validator owner
     */
    function getValidatorOwner(address validatorContract) external view returns (address owner);

    /**
     * @dev Returns information about a validator
     * @param validator Address of the validator
     * @return ValidatorInfo struct containing validator details
     */
    function getValidatorInfo(address validator) external view returns (ValidatorInfo memory);

    /**
     * @dev Returns all validators supporting an asset type
     * @param assetTypeId ID of the asset type
     * @return Array of validator addresses
     */
    function getValidatorsForAssetType(uint256 assetTypeId) external view returns (address[] memory);

    /**
     * @dev Checks if a validator is active
     * @param validator Address of the validator to check
     * @return Boolean indicating validator status
     */
    function isValidatorActive(address validator) external view returns (bool);

    /**
     * @dev Checks if a validator is registered
     * @param validator Address of the validator
     * @return Boolean indicating if the validator is registered
     */
    function isValidatorRegistered(address validator) external view returns (bool);

    /**
     * @dev Gets the name of a validator
     * @param validator Address of the validator
     * @return Name of the validator
     */
    function getValidatorName(address validator) external view returns (string memory);
}
