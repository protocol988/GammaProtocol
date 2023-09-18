// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

pragma experimental ABIEncoderV2;

import {IERC20} from "../packages/oz/IERC20.sol";
import {Actions} from "../libs/Actions.sol";

/**
 "interface" for Controller, some methods we need to call in the wrapper
*/

interface IController {
    function operate(Actions.ActionArgs[] memory _actions) external;

    function getPayout(address _otoken, uint256 _amount) external view returns (uint256);

    function getAccountVaultCounter(address _accountOwner) external view returns (uint256);
}
