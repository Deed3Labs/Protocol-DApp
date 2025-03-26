// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

/**
 * @title IERC7572 External Metadata Extension for NFTs
 * @dev Interface for the ERC7572 standard
 */
interface IERC7572 {
    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(address tokenContract, uint256 tokenId) external view returns (string memory);
}