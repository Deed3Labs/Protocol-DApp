// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

import "./IERC7572.sol";

/**
 * @title IMetadataRenderer
 * @dev Interface for metadata renderer contracts
 */
interface IMetadataRenderer is IERC7572 {
    /**
     * @dev Generates token URI for a specific token
     * @param tokenContract Address of the token contract
     * @param tokenId ID of the token
     * @return URI for the token metadata
     */
    function tokenURI(address tokenContract, uint256 tokenId) external view returns (string memory);
    
    /**
     * @dev Updates asset details for a token
     * @param tokenId ID of the token
     * @param assetType Type of the asset
     * @param details JSON string containing the details to update
     */
    function updateAssetDetails(uint256 tokenId, uint8 assetType, string memory details) external;
    
    /**
     * @dev Sets the token gallery
     * @param tokenId ID of the token
     * @param imageUrls Array of image URLs
     */
    function setTokenGallery(uint256 tokenId, string[] memory imageUrls) external;
    
    /**
     * @dev Gets token gallery images
     * @param tokenId ID of the token
     * @return Array of image URLs
     */
    function getTokenGallery(uint256 tokenId) external view returns (string[] memory);
    
    /**
     * @dev Sets features for a token
     * @param tokenId ID of the token
     * @param features Array of feature strings
     */
    function setTokenFeatures(uint256 tokenId, string[] memory features) external;
    
    /**
     * @dev Gets features for a token
     * @param tokenId ID of the token
     * @return Array of feature strings
     */
    function getTokenFeatures(uint256 tokenId) external view returns (string[] memory);
    
    /**
     * @dev Sets a document for a token
     * @param tokenId ID of the token
     * @param docType Type of document
     * @param documentURI URI of the document
     */
    function setTokenDocument(uint256 tokenId, string memory docType, string memory documentURI) external;
    
    /**
     * @dev Gets a document for a token
     * @param tokenId ID of the token
     * @param docType Type of document
     * @return URI of the document
     */
    function getTokenDocument(uint256 tokenId, string memory docType) external view returns (string memory);
    
    /**
     * @dev Gets all document types for a token
     * @param tokenId ID of the token
     * @return Array of document type strings
     */
    function getTokenDocumentTypes(uint256 tokenId) external view returns (string[] memory);
    
    /**
     * @dev Sets multiple documents for a token
     * @param tokenId ID of the token
     * @param docTypes Array of document types
     * @param documentURIs Array of document URIs
     */
    function setTokenDocuments(uint256 tokenId, string[] memory docTypes, string[] memory documentURIs) external;
    
    /**
     * @dev Removes a document from a token
     * @param tokenId ID of the token
     * @param docType Type of document to remove
     */
    function removeTokenDocument(uint256 tokenId, string memory docType) external;
    
    /**
     * @dev Sets the DeedNFT contract address
     * @param deedNFT Address of the DeedNFT contract
     */
    function setDeedNFT(address deedNFT) external;
} 