// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

// OpenZeppelin Upgradeable Contracts
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

// Interfaces
import "./interfaces/IValidatorRegistry.sol";
import "./interfaces/IDeedNFT.sol";
import "./interfaces/IValidator.sol";
import "./interfaces/IFundManager.sol";

/**
 * @title FundManager
 * @dev Contract for managing financial operations related to DeedNFTs.
 *      Handles commission collection and distribution from validator fees.
 *      Works with DeedNFT that implements ERC721C for on-chain royalty enforcement.
 */
contract FundManager is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    IFundManager
{
    using StringsUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    // ============ Role Definitions ============
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");

    // ============ State Variables ============
    address public deedNFTContract;
    address public validatorRegistry;
    uint256 private _commissionPercentage;
    address public feeReceiver;
    
    // Mapping to track validator balances per token
    mapping(address => mapping(address => uint256)) private validatorBalances;
    
    /**
     * @dev Initializes the contract.
     * @param _deedNFT Address of the DeedNFT contract.
     * @param _validatorRegistry Address of the validator registry.
     * @param initialCommissionPercentage Initial commission percentage in basis points.
     * @param _feeReceiver Address that receives commission fees.
     */
    function initialize(
        address _deedNFT,
        address _validatorRegistry,
        uint256 initialCommissionPercentage,
        address _feeReceiver
    ) public initializer {
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        
        require(_deedNFT != address(0), "FundManager: Invalid DeedNFT address");
        require(_validatorRegistry != address(0), "FundManager: Invalid ValidatorRegistry address");
        require(_feeReceiver != address(0), "FundManager: Invalid fee receiver address");
        require(initialCommissionPercentage <= 10000, "FundManager: Commission percentage exceeds 100%");
        
        deedNFTContract = _deedNFT;
        validatorRegistry = _validatorRegistry;
        _commissionPercentage = initialCommissionPercentage;
        feeReceiver = _feeReceiver;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(FEE_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Authorizes an upgrade to a new implementation.
     * @param newImplementation Address of the new implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
    
    // ============ Admin Functions ============
    
    /**
     * @dev Sets the commission percentage.
     * @param newCommissionPercentage New commission percentage in basis points.
     */
    function setCommissionPercentage(uint256 newCommissionPercentage) external onlyRole(ADMIN_ROLE) {
        require(newCommissionPercentage <= 10000, "FundManager: Commission percentage exceeds 100%");
        _commissionPercentage = newCommissionPercentage;
        emit CommissionPercentageUpdated(newCommissionPercentage);
    }
    
    /**
     * @dev Sets the fee receiver address.
     * @param _feeReceiver New fee receiver address.
     */
    function setFeeReceiver(address _feeReceiver) external onlyRole(ADMIN_ROLE) {
        require(_feeReceiver != address(0), "FundManager: Invalid fee receiver address");
        feeReceiver = _feeReceiver;
        emit FeeReceiverUpdated(_feeReceiver);
    }
    
    /**
     * @dev Sets the validator registry address.
     * @param _validatorRegistry New validator registry address.
     */
    function setValidatorRegistry(address _validatorRegistry) external onlyRole(ADMIN_ROLE) {
        require(_validatorRegistry != address(0), "FundManager: Invalid validator registry address");
        validatorRegistry = _validatorRegistry;
        emit ValidatorRegistryUpdated(_validatorRegistry);
    }
    
    /**
     * @dev Sets the DeedNFT contract address.
     * @param _deedNFT New DeedNFT contract address.
     */
    function setDeedNFT(address _deedNFT) external onlyRole(ADMIN_ROLE) {
        require(_deedNFT != address(0), "FundManager: Invalid DeedNFT address");
        deedNFTContract = _deedNFT;
        emit DeedNFTUpdated(_deedNFT);
    }

    // ============ Minting Functions ============
    
    /**
     * @dev Mints a new deed NFT.
     * @param owner Address of the owner.
     * @param assetType Type of asset.
     * @param ipfsDetailsHash IPFS hash of details.
     * @param definition Definition of the deed.
     * @param configuration Configuration of the deed.
     * @param validatorAddress Address of the validator.
     * @param token Address of the token.
     * @param salt Optional value used to generate a unique token ID
     * @return The ID of the minted deed.
     */
    function mintDeedNFT(
        address owner,
        IDeedNFT.AssetType assetType,
        string memory ipfsDetailsHash,
        string memory definition,
        string memory configuration,
        address validatorAddress,
        address token,
        uint256 salt
    ) external nonReentrant returns (uint256) {
        // Validate inputs
        require(owner != address(0), "FundManager: Invalid owner address");
        require(validatorAddress != address(0), "FundManager: Invalid validator address");
        require(token != address(0), "FundManager: Invalid token address");
        
        // Check if validator is registered
        require(
            IValidatorRegistry(validatorRegistry).isValidatorRegistered(validatorAddress),
            "FundManager: Validator not registered"
        );
        
        // Check if token is whitelisted by validator
        require(
            IValidator(validatorAddress).isTokenWhitelisted(token),
            "FundManager: Token not whitelisted by validator"
        );
        
        // Get service fee from validator
        uint256 serviceFee = IValidator(validatorAddress).getServiceFee(token);
        require(serviceFee > 0, "FundManager: Service fee not set");
        
        // Process payment
        _processPayment(msg.sender, validatorAddress, token, serviceFee);
        
        // Process mint with optional salt parameter
        uint256 tokenId = IDeedNFT(deedNFTContract).mintAsset(
            owner,
            assetType,
            ipfsDetailsHash,
            definition,
            configuration,
            validatorAddress,
            salt
        );
        
        emit DeedMinted(tokenId, owner, validatorAddress);
        
        return tokenId;
    }
    
    /**
     * @dev Mints multiple deed NFTs in a batch.
     * @param deeds Array of deed minting data.
     * @return tokenIds Array of minted deed IDs.
     */
    function mintBatchDeedNFT(DeedMintData[] memory deeds) external nonReentrant returns (uint256[] memory tokenIds) {
        uint256 length = deeds.length;
        require(length > 0, "FundManager: Empty deeds array");
        
        tokenIds = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            DeedMintData memory deed = deeds[i];
            
            // Validate inputs
            require(deed.validatorContract != address(0), "FundManager: Invalid validator address");
            require(deed.token != address(0), "FundManager: Invalid token address");
            
            // Check if validator is registered
            require(
                IValidatorRegistry(validatorRegistry).isValidatorRegistered(deed.validatorContract),
                "FundManager: Validator not registered"
            );
            
            // Check if token is whitelisted by validator
            require(
                IValidator(deed.validatorContract).isTokenWhitelisted(deed.token),
                "FundManager: Token not whitelisted by validator"
            );
            
            // Get service fee from validator
            uint256 serviceFee = IValidator(deed.validatorContract).getServiceFee(deed.token);
            require(serviceFee > 0, "FundManager: Service fee not set for token");
            
            // Process payment
            _processPayment(msg.sender, deed.validatorContract, deed.token, serviceFee);
            
            // Process mint
            tokenIds[i] = _processMint(
                msg.sender,
                deed.assetType,
                deed.ipfsDetailsHash,
                deed.definition,
                deed.configuration,
                deed.validatorContract,
                deed.salt
            );
            
            emit DeedMinted(tokenIds[i], msg.sender, deed.validatorContract);
        }
        
        return tokenIds;
    }
    
    // ============ Fee Management Functions ============
    
    /**
     * @dev Allows validator admins to withdraw their accumulated fees.
     * @param validatorContract Address of the validator contract.
     * @param token Address of the token to withdraw.
     */
    function withdrawValidatorFees(address validatorContract, address token) external nonReentrant {
        // Check if caller is authorized to withdraw fees
        require(
            IValidator(validatorContract).hasRole(keccak256("ADMIN_ROLE"), msg.sender) ||
            hasRole(FEE_MANAGER_ROLE, msg.sender),
            "FundManager: Not authorized to withdraw fees"
        );
        
        // Get balance
        uint256 amount = validatorBalances[validatorContract][token];
        require(amount > 0, "FundManager: No fees to withdraw");
        
        // Reset balance before transfer to prevent reentrancy
        validatorBalances[validatorContract][token] = 0;
        
        // Transfer tokens to the validator
        IERC20Upgradeable(token).safeTransfer(validatorContract, amount);
        
        emit ValidatorFeesWithdrawn(validatorContract, token, amount, msg.sender);
    }
    
    /**
     * @dev Gets the commission balance for a validator and token.
     * @param validatorContract Address of the validator.
     * @param token Address of the token.
     * @return The commission balance.
     */
    function getCommissionBalance(address validatorContract, address token) external view returns (uint256) {
        return validatorBalances[validatorContract][token];
    }
    
    // ============ Getter Functions ============
    
    /**
     * @dev Gets the commission percentage.
     * @return The commission percentage in basis points.
     */
    function getCommissionPercentage() external view returns (uint256) {
        return _commissionPercentage;
    }
    
    /**
     * @dev Gets the commission percentage (alias for getCommissionPercentage).
     * @return The commission percentage in basis points.
     */
    function commissionPercentage() external view returns (uint256) {
        return _commissionPercentage;
    }
    
    /**
     * @dev Gets the DeedNFT contract address.
     * @return The DeedNFT contract address.
     */
    function deedNFT() external view returns (address) {
        return deedNFTContract;
    }

    /**
     * @dev Formats a fee amount.
     * @param amount Amount to format.
     * @return The formatted fee as a string.
     */
    function formatFee(uint256 amount) external pure returns (string memory) {
        return amount.toString();
    }

    // ============ Internal Functions ============
    
    /**
     * @dev Processes a payment.
     * @param payer Address of the payer.
     * @param validatorAddress Address of the validator.
     * @param token Address of the token.
     * @param serviceFee Service fee amount.
     */
    function _processPayment(
        address payer,
        address validatorAddress,
        address token,
        uint256 serviceFee
    ) internal {
        // Calculate commission amount
        uint256 commissionAmount = (serviceFee * _commissionPercentage) / 10000;
        uint256 validatorAmount = serviceFee - commissionAmount;
        
        // Transfer tokens from payer to this contract
        IERC20Upgradeable(token).safeTransferFrom(payer, address(this), serviceFee);
        
        // Update validator balance
        validatorBalances[validatorAddress][token] += validatorAmount;
        
        // Transfer commission to fee receiver
        if (commissionAmount > 0) {
            IERC20Upgradeable(token).safeTransfer(feeReceiver, commissionAmount);
        }
        
        emit ServiceFeeCollected(validatorAddress, token, serviceFee, commissionAmount);
    }
    
    /**
     * @dev Processes a mint.
     * @param owner Address of the owner.
     * @param assetType Type of asset.
     * @param ipfsDetailsHash IPFS hash of details.
     * @param definition Definition of the deed.
     * @param configuration Configuration of the deed.
     * @param validatorAddress Address of the validator.
     * @param salt Optional value used to generate a unique token ID
     * @return The ID of the minted deed.
     */
    function _processMint(
        address owner,
        IDeedNFT.AssetType assetType,
        string memory ipfsDetailsHash,
        string memory definition,
        string memory configuration,
        address validatorAddress,
        uint256 salt
    ) internal returns (uint256) {
        // Mint the deed
        uint256 tokenId = IDeedNFT(deedNFTContract).mintAsset(
            owner,
            assetType,
            ipfsDetailsHash,
            definition,
            configuration,
            validatorAddress,
            salt
        );
        
        emit DeedMinted(tokenId, owner, validatorAddress);
        
        return tokenId;
    }
}
