/**
 * SPDX-License-Identifier: UNLICENSED

 This contract acts a wrapper for working with the Controller. It is used to create Forwards
 Destroy Forwards, and exercise Forwards. The reason we work with a wrapper contract and not
 the controller directly is that we are frantionalizing ownership of the forward represented in
 the vault, and paying the minter in ERC-20 tokens.
*/
pragma solidity ^0.6.10; // necessary for string concatenation

pragma experimental ABIEncoderV2;

import "./FShare.sol";

import {Actions} from "../libs/Actions.sol";
import {ReentrancyGuard} from "../packages/oz/ReentrancyGuard.sol";
import {OtokenInterface} from "../interfaces/OtokenInterface.sol";
import {IController} from "../interfaces/controllerProxy.sol";
import {SafeMath} from "../packages/oz/SafeMath.sol";
import {IERC20} from "../packages/oz/IERC20.sol";
import {IFShare} from "../interfaces/FShareInterface.sol";
import {OtokenFactory} from "./OtokenFactory.sol";

/**
 * @title Wrapper
 * @author Rashad Hadddad (github: rashadalh)
 * @notice user interface for controller
 */
contract Wrapper is ReentrancyGuard {
    using SafeMath for uint256;

    // Controller contract
    address public controller;
    OtokenFactory public otokenFactory;

    mapping(address => address[]) public longFShareAddressesOwned;
    mapping(address => address[]) public ShortFShareAddressesOwned;
    mapping(address => uint256) public amountMinted;
    mapping(address => bool) public fShareExpired;
    mapping(address => uint256) public payout;

    constructor(address controller_address, address _otokenFactory) public {
        controller = controller_address;
        otokenFactory = OtokenFactory(_otokenFactory);
    }

    function mintForwardQuick(
        address owner,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        address _collateralAsset,
        uint256 _collateralAmount,
        uint256 _expiry,
        uint256 _oTokenAmount
    ) public nonReentrant returns (address[] memory) {
        /////////////////////////////////
        //OtokenInterface otoken = OtokenInterface(oTokenShort);

        uint256 _amount = _oTokenAmount;

        // mint oTokens here...

        address oTokenPut = otokenFactory.createOtoken(
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            true
        );

        address oTokenCall = otokenFactory.createOtoken(
            _underlyingAsset,
            _strikeAsset,
            _collateralAsset,
            _strikePrice,
            _expiry,
            false
        );

        // get number of vaults in the Controller
        uint256 vaultCounter = IController(controller).getAccountVaultCounter(owner);

        // create actions for controller
        // First action, open a vault.
        Actions.ActionArgs[] memory actions = new Actions.ActionArgs[](3);
        actions[0] = Actions.ActionArgs(
            Actions.ActionType.OpenVault,
            owner, // owner
            address(this), // receiver
            oTokenCall, // call (will be long otoken for forwards.)
            oTokenPut, // put (will be short otoken for forwards.)
            vaultCounter + 1, // vaultId
            _amount, // amount
            0, // index // can leave at 0
            "" // data // empty string
        );
        // Second action, deposit collateral.
        actions[1] = Actions.ActionArgs(
            Actions.ActionType.DepositCollateral,
            owner, // owner
            address(this), // receiver
            _collateralAsset, // asset, parse args will assign this to the collateralAsset.
            _collateralAsset, // doesn't matter will be ignored...
            vaultCounter + 1, // vaultId
            _collateralAmount, // amount
            0, // index // can leave at 0
            "" // data // empty string
        );
        // Third action, mint Forward (MintForward)
        actions[2] = Actions.ActionArgs(
            Actions.ActionType.MintForward,
            owner, // owner
            address(this), // receiver
            oTokenCall, // long
            oTokenPut, // otoken
            vaultCounter + 1, // vaultId
            _amount, // amount
            0, // index // can leave at 0
            "" // data // empty string
        );

        // run actions
        IController(controller).operate(actions);

        // GENERATE THE FSHARES
        // NOTE, The call is always long, the put is always short

        OtokenInterface IoTokenCall = OtokenInterface(oTokenCall);
        OtokenInterface IoTokenPut = OtokenInterface(oTokenPut);

        // name the fShare's
        // TODO convert expiry and strike to strs
        // TODO get short name of Otoken, or add method to OToken contract for this...
        string memory name_long = append("_", "LFTOKEN", "_", "_"); //, IoTokenCall.expiryTimestamp(), IoTokenCall.strikePrice());
        // IoTokenPut.underlyingAsset()
        string memory name_short = append("_", "SFTOKEN", "_", "_"); //, IoTokenPut.expiryTimestamp(), IoTokenPut.strikePrice());

        // initial supply is the amount minted * 1000 // TODO optimize this quantity based on asset
        uint256 amount = _amount * 1000;
        FShare fShareLong = new FShare(name_long, name_long, amount, true, _collateralAsset);
        FShare fShareShort = new FShare(name_short, name_short, amount, false, _collateralAsset);

        // make the wrapper contract an approved spender of the all the fShares
        fShareLong.approve(address(this), amount);
        fShareShort.approve(address(this), amount);

        // store the amount minted
        amountMinted[address(fShareLong)] = _amount;
        amountMinted[address(fShareShort)] = _amount;

        // set the fShare as NOT expired
        fShareExpired[address(fShareLong)] = false;
        fShareExpired[address(fShareShort)] = false;

        // store the fShare addresses owned by the msg.sender
        longFShareAddressesOwned[msg.sender].push(address(fShareLong));
        ShortFShareAddressesOwned[msg.sender].push(address(fShareShort));

        // transfer the fShares to the msg.sender
        fShareLong.transfer(msg.sender, _amount);
        fShareShort.transfer(msg.sender, _amount);

        // return the fShare addresses
        address[] memory fShareAddresses = new address[](2);
        fShareAddresses[0] = address(fShareLong);
        fShareAddresses[1] = address(fShareShort);
        return fShareAddresses;
    }

    /**
     * @notice mints a forward, and returns the fShares to the minter
     */
    function mintForward(Actions.ActionArgs[] memory _actions) public nonReentrant returns (address[] memory) {
        // TODO - reintroduce real logic!
        /*
        // verify that the Actions include OpenVault, DepositCollateral, MintForward in that order
        require(_actions.length == 3, "Wrapper: invalid actions length");
        require(_actions[0].actionType == Actions.ActionType.OpenVault, "Wrapper: first action must be OpenVault");
        require(
            _actions[1].actionType == Actions.ActionType.DepositCollateral,
            "Wrapper: second action must be DepositCollateral"
        );
        require(_actions[2].actionType == Actions.ActionType.MintForward, "Wrapper: third action must be MintForward");

        // run the actions
        IController(controller).operate(_actions);
        */

        // Create a new fShare token, and transfer it to the msg.sender
        // create instance of short otoken from actions
        OtokenInterface otoken = OtokenInterface(_actions[2].shortAsset);

        // name the fShare's
        string memory name_long = string(
            abi.encodePacked(otoken.underlyingAsset(), "LONG-F", otoken.expiryTimestamp(), otoken.strikePrice())
        );
        string memory name_short = string(
            abi.encodePacked(otoken.underlyingAsset(), "SHORT-F", otoken.expiryTimestamp(), otoken.strikePrice())
        );

        // initial supply is the amount minted * 1000
        uint256 amount = _actions[2].amount * 1000;
        FShare fShareLong = new FShare(name_long, name_long, amount, true, _actions[1].asset);
        FShare fShareShort = new FShare(name_short, name_short, amount, false, _actions[1].shortAsset);

        // make the wrapper contract an approved spender of the all the fShares
        fShareLong.approve(address(this), amount);
        fShareShort.approve(address(this), amount);

        // store the amount minted
        amountMinted[address(fShareLong)] = _actions[2].amount;
        amountMinted[address(fShareShort)] = _actions[2].amount;

        // set the fShare as NOT expired
        fShareExpired[address(fShareLong)] = false;
        fShareExpired[address(fShareShort)] = false;

        // store the fShare addresses owned by the msg.sender
        longFShareAddressesOwned[msg.sender].push(address(fShareLong));
        ShortFShareAddressesOwned[msg.sender].push(address(fShareShort));

        // transfer the fShares to the msg.sender
        fShareLong.transfer(msg.sender, amount);
        fShareShort.transfer(msg.sender, amount);

        // return the fShare addresses
        address[] memory fShareAddresses = new address[](2);
        fShareAddresses[0] = address(fShareLong);
        fShareAddresses[1] = address(fShareShort);
        return fShareAddresses;
    }

    /**
     * @notice burns a forward, and returns the collateral to the minter
     */
    function burnForward(
        Actions.ActionArgs[] memory _actions,
        address longFShare,
        address shortFShare
    ) public nonReentrant {
        // verify that the Actions include BurnForward, WithdrawCollateral, SettleVault in that order
        require(_actions.length == 3, "Wrapper: invalid actions length");
        require(_actions[0].actionType == Actions.ActionType.BurnForward, "Wrapper: first action must be BurnForward");
        require(
            _actions[1].actionType == Actions.ActionType.WithdrawCollateral,
            "Wrapper: second action must be WithdrawCollateral"
        );
        require(_actions[2].actionType == Actions.ActionType.SettleVault, "Wrapper: third action must be CloseVault");

        // verify that "to" address for SettleVault is the associated address of the Wrapper contract
        require(
            _actions[2].owner == address(this),
            "Wrapper: SettleVault must be called with the associated address of the wrapper"
        );

        // TODO - reintroduce checks, failed compilation with error:
        // TypeError: Member "contains" not found or not visible after argument-dependent lookup in address[] storage ref.
        // verify that the fShare addresses are owned by the msg.sender
        /*
        require(
            longFShareAddressesOwned[msg.sender].contains(longFShare),
            "Wrapper: long fShare address not owned by msg.sender"
        );
        require(
            ShortFShareAddressesOwned[msg.sender].contains(shortFShare),
            "Wrapper: short fShare address not owned by msg.sender"
        );
        */

        // verify that the fShares hold the oToken
        IFShare longFShareInstance = IFShare(longFShare);
        IFShare shortFShareInstance = IFShare(shortFShare);
        // TODO - reintroduce checks, failed compilation with error:
        // TypeError: Member "getOtoken" not found or not visible after argument-dependent lookup in contract IFShare.
        /*
        require(longFShareInstance.getOtoken() == _actions[0].asset, "Wrapper: long fShare does not hold the oToken");
        require(
            shortFShareInstance.getOtoken() == _actions[0].otoken,
            "Wrapper: short fShare does not hold the oToken"
        );
        */

        IController contrl = IController(controller);
        // run the actions
        contrl.operate(_actions);

        // fetch the long and short oToken addresses
        OtokenInterface longOtoken = OtokenInterface(_actions[0].asset);
        // TODO - verify this fix was correct
        //OtokenInterface shortOtoken = OtokenInterface(_actions[0].otoken);
        OtokenInterface shortOtoken = OtokenInterface(_actions[0].shortAsset);

        // get the payout from the controller, store it
        payout[address(longFShare)] = contrl.getPayout(address(longOtoken), _actions[0].amount);
        payout[address(shortFShare)] = contrl.getPayout(address(shortOtoken), _actions[0].amount);

        // set the fShare as expired

        // get the payout from the controller, store it
        payout[address(longFShare)] = contrl.getPayout(address(longOtoken), _actions[0].amount);
        payout[address(shortFShare)] = contrl.getPayout(address(shortOtoken), _actions[0].amount);

        // set the fShare as expired
        fShareExpired[address(longFShare)] = true;
        fShareExpired[address(shortFShare)] = true;

        // transfer the collateral to the Wrapper contract
        IERC20 collateral = IERC20(_actions[1].asset);
        collateral.transfer(address(this), _actions[1].amount);
    }

    /**
     * @notice allows withdraw based on the fShare address and amount
     */
    function redeemCollateral(
        address fTokenAddress,
        uint256 ftokens,
        uint256 price
    ) public nonReentrant {
        // get the fShare instance
        IFShare fShare = IFShare(fTokenAddress);

        //TODO - address this error
        //TypeError: Member "getCollateral" not found or not visible after argument-dependent lookup in contract IFShare.

        /*
        if (fShare.isLong()) {
            // fetch the payout
            uint256 payoutAmount = payout[fTokenAddress];

            // fetch the share of the payout
            uint256 share = payoutAmount.mul(ftokens).div(amountMinted[fTokenAddress]);

            // fetch the collateral
            IERC20 collateral = IERC20(fShare.getCollateral());

            //

            // transfer the collateral to the msg.sender, in proportion to the payout share
            collateral.transfer(msg.sender, share.mul(price).div(1e8));
        } else {
            // fetch the payout
            uint256 payoutAmount = payout[fTokenAddress];

            // fetch the share of the payout
            uint256 share = payoutAmount.mul(ftokens).div(amountMinted[fTokenAddress]);

            // fetch the collateral
            IERC20 collateral = IERC20(fShare.getCollateral());

            // transfer the collateral to the msg.sender, in proportion to the payout share
            collateral.transfer(msg.sender, share.mul(price).div(1e8));
        }
        */
    }

    // event to emit whenever ether is received
    event Received(address sender, uint256 amount);

    // payable fallback function
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function append(
        string memory a,
        string memory b,
        string memory c,
        string memory d
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d));
    }
}
