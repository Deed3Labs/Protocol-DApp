// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.29;

import "./StringUtils.sol";

/**
 * @title JSONUtils
 * @dev Library for JSON generation
 */
library JSONUtils {
    using StringUtils for string;
    
    /**
     * @dev Creates a JSON trait
     */
    function createTrait(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked('{"trait_type":"', traitType, '","value":"', value, '"}'));
    }
    
    /**
     * @dev Adds a trait to attributes array if value is not empty
     */
    function addTraitIfNotEmpty(string memory attributes, string memory traitType, string memory value) internal pure returns (string memory) {
        if (bytes(value).length == 0) {
            return attributes;
        }
        
        string memory separator = bytes(attributes).length > 0 ? "," : "";
        return string(abi.encodePacked(attributes, separator, createTrait(traitType, value)));
    }
    
    /**
     * @dev Creates a JSON object with key-value pair
     */
    function createJSONObject(string memory key, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked('"', key, '":"', value, '"'));
    }
    
    /**
     * @dev Adds a string array to JSON
     */
    function addStringArray(string memory json, string memory arrayName, string[] memory items) internal pure returns (string memory) {
        if (items.length == 0) {
            return json;
        }
        
        string memory arrayJson = string(abi.encodePacked('"', arrayName, '":['));
        
        for (uint i = 0; i < items.length; i++) {
            if (i > 0) {
                arrayJson = string(abi.encodePacked(arrayJson, ','));
            }
            arrayJson = string(abi.encodePacked(arrayJson, '"', items[i], '"'));
        }
        
        arrayJson = string(abi.encodePacked(arrayJson, ']'));
        
        return string(abi.encodePacked(json, ',', arrayJson));
    }
    
    /**
     * @dev Adds a string-to-string mapping to JSON as an object
     */
    function addStringMap(string memory json, string memory mapName, string[] memory keys, mapping(string => string) storage values) internal view returns (string memory) {
        if (keys.length == 0) {
            return json;
        }
        
        string memory mapJson = string(abi.encodePacked('"', mapName, '":{'));
        
        for (uint i = 0; i < keys.length; i++) {
            if (i > 0) {
                mapJson = string(abi.encodePacked(mapJson, ','));
            }
            string memory key = keys[i];
            string memory value = values[key];
            mapJson = string(abi.encodePacked(mapJson, '"', key, '":"', value, '"'));
        }
        
        mapJson = string(abi.encodePacked(mapJson, '}'));
        
        return string(abi.encodePacked(json, ',', mapJson));
    }

    /**
     * @dev Parses a JSON array string into an array of strings
     * @param jsonArray JSON array string (e.g., ["url1", "url2", "url3"])
     * @return Array of strings
     */
    function parseJsonArrayToStringArray(string memory jsonArray) internal pure returns (string[] memory) {
        bytes memory jsonBytes = bytes(jsonArray);
        uint256 count = 0;
        
        // Count the number of elements in the array
        for (uint256 i = 0; i < jsonBytes.length; i++) {
            if (jsonBytes[i] == '"') {
                count++;
                // Skip to the closing quote
                i++;
                while (i < jsonBytes.length && jsonBytes[i] != '"') {
                    if (jsonBytes[i] == '\\' && i + 1 < jsonBytes.length) {
                        i += 2; // Skip escaped character
                    } else {
                        i++;
                    }
                }
            }
        }
        
        // Divide by 2 because we counted opening and closing quotes
        count = count / 2;
        
        string[] memory result = new string[](count);
        uint256 index = 0;
        
        // Extract the strings
        for (uint256 i = 0; i < jsonBytes.length && index < count; i++) {
            if (jsonBytes[i] == '"') {
                uint256 start = i + 1;
                i++;
                
                // Find the closing quote
                while (i < jsonBytes.length && jsonBytes[i] != '"') {
                    if (jsonBytes[i] == '\\' && i + 1 < jsonBytes.length) {
                        i += 2; // Skip escaped character
                    } else {
                        i++;
                    }
                }
                
                // Extract the string
                uint256 length = i - start;
                bytes memory valueBytes = new bytes(length);
                for (uint256 j = 0; j < length; j++) {
                    valueBytes[j] = jsonBytes[start + j];
                }
                
                result[index] = string(valueBytes);
                index++;
            }
        }
        
        return result;
    }

    /**
     * @dev Extracts a field value from a JSON object
     * @param json JSON object string
     * @param fieldName Name of the field to extract
     * @return Value of the field as a string
     */
    function parseJsonField(string memory json, string memory fieldName) internal pure returns (string memory) {
        bytes memory jsonBytes = bytes(json);
        bytes memory fieldNameBytes = bytes(fieldName);
        
        // Find the field in the JSON
        uint256 i = 0;
        while (i < jsonBytes.length) {
            // Look for the field name with quotes and colon
            if (jsonBytes[i] == '"') {
                bool fieldMatch = true;
                uint256 j = 0;
                
                // Check if this is our field
                for (j = 0; j < fieldNameBytes.length && i + j + 1 < jsonBytes.length; j++) {
                    if (jsonBytes[i + j + 1] != fieldNameBytes[j]) {
                        fieldMatch = false;
                        break;
                    }
                }
                
                // If field name matches, extract the value
                if (fieldMatch && i + j + 1 < jsonBytes.length && jsonBytes[i + j + 1] == '"') {
                    // Skip to the value (after the colon and any whitespace)
                    i = i + j + 2;
                    while (i < jsonBytes.length && jsonBytes[i] != ':') i++;
                    i++; // Skip the colon
                    
                    // Skip any whitespace
                    while (i < jsonBytes.length && (jsonBytes[i] == ' ' || jsonBytes[i] == '\t' || jsonBytes[i] == '\n' || jsonBytes[i] == '\r')) i++;
                    
                    // Check if the value is a string
                    if (i < jsonBytes.length && jsonBytes[i] == '"') {
                        i++; // Skip the opening quote
                        uint256 start = i;
                        
                        // Find the closing quote
                        while (i < jsonBytes.length && jsonBytes[i] != '"') {
                            if (jsonBytes[i] == '\\' && i + 1 < jsonBytes.length) {
                                i += 2; // Skip escaped character
                            } else {
                                i++;
                            }
                        }
                        
                        // Extract the string value
                        uint256 length = i - start;
                        bytes memory valueBytes = new bytes(length);
                        for (j = 0; j < length; j++) {
                            valueBytes[j] = jsonBytes[start + j];
                        }
                        
                        return string(valueBytes);
                    }
                    // Handle non-string values (numbers, booleans, etc.)
                    else {
                        uint256 start = i;
                        
                        // Find the end of the value (comma or closing brace/bracket)
                        while (i < jsonBytes.length && jsonBytes[i] != ',' && jsonBytes[i] != '}' && jsonBytes[i] != ']') {
                            i++;
                        }
                        
                        // Extract the value
                        uint256 length = i - start;
                        bytes memory valueBytes = new bytes(length);
                        for (j = 0; j < length; j++) {
                            valueBytes[j] = jsonBytes[start + j];
                        }
                        
                        return string(valueBytes);
                    }
                }
            }
            
            i++;
        }
        
        return ""; // Field not found
    }
} 