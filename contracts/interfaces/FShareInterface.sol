// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IFShare {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external pure returns (uint8);

    function isLong() external view returns (bool);

    function oToken() external view returns (address);
}
