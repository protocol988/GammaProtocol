// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {IFShare} from "../interfaces/FShareInterface.sol";
import {IERC20} from "../packages/oz/IERC20.sol";

/**
 interface for FShare
*/

contract FShare is IERC20, IFShare {
    string private _name;
    string private _symbol;
    uint256 private _totalSupply;

    bool public _isLong;

    address _Otoken;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        bool isLong,
        address Otoken
    ) public {
        _name = name;
        _symbol = symbol;
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply;
        _isLong = isLong;
        _Otoken = Otoken;
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    function oToken() external view override returns (address) {
        return _Otoken;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return 18; // standard for ERC-20
    }

    function isLong() external view override returns (bool) {
        return _isLong;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(msg.sender, recipient, amount);

        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        require(spender != address(0), "Approve to the zero address");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Insufficient balance");
        require(_allowances[sender][msg.sender] >= amount, "Transfer amount exceeds allowance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);

        return true;
    }
}
