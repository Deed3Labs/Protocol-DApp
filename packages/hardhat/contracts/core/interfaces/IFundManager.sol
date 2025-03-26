// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

import "../interfaces/IDeedNFT.sol";

/**
 * @title IFundManager
 * @dev Interface for the FundManager contract to allow other contracts to interact with it.
 *      Focuses on commission collection, minting operations, and validator fee distribution.
 */
interface IFundManager {
    // ============ Structs ============
    
    /**
     * @dev Struct for batch minting data
     */
    struct DeedMintData {
        IDeedNFT.AssetType assetType;
        string ipfsDetailsHash;
        string definition;
        string configuration;
        address validatorContract;
        address token;
    }

    // ============ Events ============

    /**
     * @dev Emitted when the commission percentage is updated
     * @param newCommissionPercentage The new commission percentage in basis points
     */
    event CommissionPercentageUpdated(uint256 newCommissionPercentage);

    /**
     * @dev Emitted when the fee receiver address is updated
     * @param newFeeReceiver The new fee receiver address
     */
    event FeeReceiverUpdated(address indexed newFeeReceiver);

    /**
     * @dev Emitted when the ValidatorRegistry address is updated
     * @param newValidatorRegistry The new ValidatorRegistry address
     */
    event ValidatorRegistryUpdated(address indexed newValidatorRegistry);

    /**
     * @dev Emitted when the DeedNFT contract address is updated
     * @param newDeedNFT The new DeedNFT contract address
     */
    event DeedNFTUpdated(address indexed newDeedNFT);

    /**
     * @dev Emitted when a service fee is collected
     * @param validator Address of the validator
     * @param token Address of the token
     * @param amount Total amount collected
     * @param commission Commission amount taken
     */
    event ServiceFeeCollected(
        address indexed validator,
        address indexed token,
        uint256 amount,
        uint256 commission
    );

    /**
     * @dev Emitted when a deed is minted
     * @param tokenId ID of the minted deed
     * @param owner Address of the deed owner
     * @param validator Address of the validator
     */
    event DeedMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed validator
    );
    
    /**
     * @dev Emitted when validator fees are withdrawn
     * @param validator Address of the validator
     * @param token Address of the token
     * @param amount Amount withdrawn
     * @param recipient Address receiving the funds
     */
    event ValidatorFeesWithdrawn(
        address indexed validator,
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    // ============ Administrative Functions ============

    /**
     * @dev Sets the commission percentage
     * @param _percentage New commission percentage in basis points (e.g., 500 = 5%)
     */
    function setCommissionPercentage(uint256 _percentage) external;

    /**
     * @dev Sets the fee receiver address
     * @param _feeReceiver New fee receiver address
     */
    function setFeeReceiver(address _feeReceiver) external;

    /**
     * @dev Sets the ValidatorRegistry contract address
     * @param _validatorRegistry New ValidatorRegistry contract address
     */
    function setValidatorRegistry(address _validatorRegistry) external;

    /**
     * @dev Sets the DeedNFT contract address
     * @param _deedNFT New DeedNFT contract address
     */
    function setDeedNFT(address _deedNFT) external;

    // ============ Minting Functions ============

    /**
     * @dev Allows users to deposit funds and mint a single DeedNFT in a single transaction
     * @param owner Address of the owner
     * @param assetType Type of the asset
     * @param ipfsDetailsHash IPFS hash of the deed details
     * @param definition Definition of the deed
     * @param configuration Configuration data for the deed
     * @param validatorContract Address of the ValidatorContract associated with the mint
     * @param token Address of the token being used for payment
     * @return tokenId The ID of the minted deed
     */
    function mintDeedNFT(
        address owner,
        IDeedNFT.AssetType assetType,
        string memory ipfsDetailsHash,
        string memory definition,
        string memory configuration,
        address validatorContract,
        address token
    ) external returns (uint256 tokenId);

    /**
     * @dev Batch mints multiple DeedNFTs
     * @param deeds Array of DeedMintData structs containing data for each deed to mint
     * @return tokenIds Array of minted deed IDs
     */
    function mintBatchDeedNFT(DeedMintData[] memory deeds) external returns (uint256[] memory tokenIds);

    // ============ Fee Management Functions ============

    /**
     * @dev Allows validator admins to withdraw their accumulated fees
     * @param validatorContract Address of the validator contract
     * @param token Address of the token to withdraw
     */
    function withdrawValidatorFees(address validatorContract, address token) external;

    /**
     * @dev Retrieves the current commission balance for a specific validator and token
     * @param validatorContract Address of the validator contract
     * @param token Address of the token
     * @return balance The current commission balance for the validator and token
     */
    function getCommissionBalance(address validatorContract, address token) external view returns (uint256);

    // ============ Getter Functions ============

    /**
     * @dev Gets the commission percentage
     * @return The commission percentage in basis points
     */
    function getCommissionPercentage() external view returns (uint256);

    /**
     * @dev Formats a fee amount to a string
     * @param amount Raw fee amount
     * @return The formatted fee string
     */
    function formatFee(uint256 amount) external pure returns (string memory);

    /**
     * @dev Gets the address of the DeedNFT contract
     * @return The address of the DeedNFT contract
     */
    function deedNFT() external view returns (address);

    /**
     * @dev Gets the address of the ValidatorRegistry contract
     * @return The address of the ValidatorRegistry contract
     */
    function validatorRegistry() external view returns (address);

    /**
     * @dev Gets the address of the fee receiver
     * @return The address of the fee receiver
     */
    function feeReceiver() external view returns (address);

    /**
     * @dev Gets the commission percentage in basis points
     * @return The commission percentage
     */
    function commissionPercentage() external view returns (uint256);
} 