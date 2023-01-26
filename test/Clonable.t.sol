// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "openzeppelin-contracts/proxy/Clones.sol";

import {Clonable} from "../src/Clonable/Clonable.sol";

contract ClonableTest is Test {
    ClonableContract original;
    address unpayableAddress = address(new Unpayable());

    address authorAddress = makeAddr("authorAddress");
    address feeRecipientAddress = makeAddr("feeRecipientAddress");
    address clonerAddress = makeAddr("clonerAddress");

    uint256 defaultNumber = 42;
    bytes32 defaultData = "";
    bytes defaultInitdata;
    uint256 defaultFeeBps = 100;

    function setUp() public {
        defaultInitdata = abi.encode(defaultNumber, defaultData);

        vm.prank(authorAddress);
        original = new ClonableContract(
            defaultNumber,
            defaultData,
            defaultFeeBps
        );
    }

    /////////////////////////////////
    // Deployment & initialization //
    /////////////////////////////////

    function testCanBeDeployed() public {
        original = new ClonableContract(defaultNumber, defaultData, defaultFeeBps);
    }

    function testCannotBeDeployedWithInvalidFeeBps() public {
        uint256 feeBasis = original.CLONING_FEE_BASIS();

        vm.expectRevert(Clonable.FeeBpsTooHigh.selector);
        original = new ClonableContract(defaultNumber, defaultData, feeBasis + 1);
    }

    function testInitializesClonable(uint8 feeBps) public {
        vm.prank(authorAddress);
        original = new ClonableContract(defaultNumber, defaultData, feeBps);

        assertEq(original.CLONABLE_ABI_VERSION(), 0);
        assertEq(original.isClone(), false);

        assertEq(original.cloningConfig().feeBps, feeBps);
        assertEq(original.cloningConfig().author, authorAddress);
        assertEq(original.cloningConfig().feeRecipient, authorAddress);
    }

    function testInitializesChildContract(uint256 someNumber, bytes32 someData) public {
        vm.assume(someNumber > 10);
        original = new ClonableContract(someNumber, someData, defaultFeeBps);

        assertEq(original.someNumber(), someNumber);
        assertEq(original.someData(), someData);
    }

    function testCannotBeInitializedAfterDeployment() public {
        vm.expectRevert("Initializable: contract is already initialized");
        original.initializeClone(defaultInitdata);
    }

    function testCanOnlyBeInitializedByOriginalContract(address randomAddress) public {
        address originalContract = address(original);
        vm.assume(randomAddress != originalContract);

        address cloneAddress = Clones.clone(originalContract);
        ClonableContract clone = ClonableContract(cloneAddress);

        vm.expectRevert(Clonable.OriginalContractOnly.selector);
        vm.prank(randomAddress);
        clone.initializeClone(defaultInitdata);

        vm.prank(originalContract);
        clone.initializeClone(defaultInitdata);
    }

    ///////////////////////////
    // Cloning configuration //
    ///////////////////////////

    function testCanUpdateCloningConfig(uint8 feeBps, address author, address feeRecipient) public {
        vm.prank(authorAddress);
        original.updateCloningConfig(Clonable.Config({author: author, feeBps: feeBps, feeRecipient: feeRecipient}));

        assertEq(original.cloningConfig().feeBps, feeBps);
        assertEq(original.cloningConfig().author, author);
        assertEq(original.cloningConfig().feeRecipient, feeRecipient);
    }

    function testClonesCallOriginalForCloningConfig() public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.expectCall(address(original), 0, abi.encodeCall(original.cloningConfig, ()));
        child.cloningConfig();
    }

    function testClonesReflectOriginalCloningConfig(uint8 feeBps, address author, address feeRecipient) public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.prank(authorAddress);
        original.updateCloningConfig(Clonable.Config({author: author, feeBps: feeBps, feeRecipient: feeRecipient}));

        assertEq(child.cloningConfig().feeBps, original.cloningConfig().feeBps);
        assertEq(child.cloningConfig().author, original.cloningConfig().author);
        assertEq(child.cloningConfig().feeRecipient, original.cloningConfig().feeRecipient);
    }

    function testCannotUpdateCloningConfigFromClones() public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.expectRevert(Clonable.NotCallableOnClones.selector);
        vm.prank(authorAddress);
        child.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: 0, feeRecipient: feeRecipientAddress})
        );
    }

    function testCannotUpdateCloningConfigIfNotTheAuthor(address notAuthor) public {
        vm.assume(notAuthor != authorAddress);

        vm.expectRevert(Clonable.AuthorOnly.selector);
        vm.prank(notAuthor);
        original.updateCloningConfig(Clonable.Config({author: notAuthor, feeBps: 0, feeRecipient: notAuthor}));
    }

    function testCannotUpdateCloningConfigWithInvalidBps() public {
        uint256 feeBasis = original.CLONING_FEE_BASIS();

        vm.expectRevert(Clonable.FeeBpsTooHigh.selector);
        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: feeBasis + 1, feeRecipient: feeRecipientAddress})
        );
    }

    /////////////////////////////
    // Cloning fee calculation //
    /////////////////////////////

    function testCanCalculateCloningFee(uint8 gasPrice) public {
        uint256 basefee = uint256(gasPrice) * 1 gwei;
        uint256 cloningFee = _calculateCloningFee(original, basefee);

        vm.fee(basefee);
        assertEq(original.cloningFee(), cloningFee);
    }

    function testClonesReflectOriginalCloningFee(uint8 gasPrice) public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.fee(uint256(gasPrice) * 1 gwei);
        assertEq(original.cloningFee(), child.cloningFee());
    }

    /////////////
    // Cloning //
    /////////////

    function testOriginalCanBeCloned(uint256 someNumber, bytes32 someData) public {
        vm.assume(someNumber > 10);

        ClonableContract child = ClonableContract(original.clone(abi.encode(someNumber, someData)));

        assertEq(child.isClone(), true);
        assertEq(child.someData(), someData);
        assertEq(child.someNumber(), someNumber);
    }

    function testCloningCallsOriginalContract() public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.expectCall(address(original), 0, abi.encodeCall(original.clone, (defaultInitdata)));
        child.clone(defaultInitdata);
    }

    function testCloneCanBeCloned(uint256 someNumber, bytes32 someData) public {
        vm.assume(someNumber > 10);

        ClonableContract child = ClonableContract(original.clone(defaultInitdata));
        ClonableContract grandchild = ClonableContract(child.clone(abi.encode(someNumber, someData)));

        assertEq(grandchild.isClone(), true);
        assertEq(grandchild.someData(), someData);
        assertEq(grandchild.someNumber(), someNumber);
    }

    function testCloneCannotBeInitializedAfterCloning() public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.expectRevert("Initializable: contract is already initialized");
        child.initializeClone(defaultInitdata);
    }

    function testCloningFailsIfCloneInitializationFails() public {
        vm.expectRevert(ClonableContract.CloneInitError.selector);
        ClonableContract(original.clone(abi.encode(3, "")));
    }

    function testCloningFromOriginalEmitsEvent() public {
        vm.expectEmit(true, false, false, false, address(original));
        emit Cloned(0, address(0));
        original.clone(defaultInitdata);
    }

    function testCloningFromCloneEmitsEvent() public {
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        vm.expectEmit(true, false, false, false, address(original));
        emit Cloned(0, address(0));
        child.clone(defaultInitdata);
    }

    ////////////////////////////
    // Cloning fee collection //
    ////////////////////////////

    function testCloningFromOriginalSendsFeeToRecipient(uint8 gasPrice, uint16 feeBps) public {
        vm.assume(gasPrice > 0);
        vm.assume(feeBps > 0);
        vm.assume(feeBps < 10000);

        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: feeBps, feeRecipient: feeRecipientAddress})
        );

        uint256 basefee = _setGasPrice(gasPrice);
        uint256 fee = _calculateCloningFee(original, basefee);
        vm.deal(clonerAddress, fee);

        assertEq(feeRecipientAddress.balance, 0);
        vm.prank(clonerAddress);
        original.clone{value: fee}(defaultInitdata);
        assertEq(feeRecipientAddress.balance, fee);
    }

    function testCloningFromCloneSendsFeeToRecipient(uint8 gasPrice, uint16 feeBps) public {
        vm.assume(gasPrice > 0);
        vm.assume(feeBps > 0);
        vm.assume(feeBps < 10000);

        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: feeBps, feeRecipient: feeRecipientAddress})
        );
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        uint256 basefee = _setGasPrice(gasPrice);
        uint256 fee = _calculateCloningFee(original, basefee);
        vm.deal(clonerAddress, fee);

        assertEq(feeRecipientAddress.balance, 0);
        vm.prank(clonerAddress);
        child.clone{value: fee}(defaultInitdata);
        assertEq(feeRecipientAddress.balance, fee);
    }

    function testCloningFailsWithInsufficientPayment(uint8 gasPrice, uint16 feeBps) public {
        vm.assume(gasPrice > 0);
        vm.assume(feeBps > 0);
        vm.assume(feeBps < 10000);

        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: feeBps, feeRecipient: feeRecipientAddress})
        );

        uint256 basefee = _setGasPrice(gasPrice);
        uint256 fee = _calculateCloningFee(original, basefee);
        vm.deal(clonerAddress, fee);

        vm.expectRevert(Clonable.MsgValueTooLow.selector);
        vm.prank(clonerAddress);
        original.clone{value: fee - 1}(defaultInitdata);
    }

    function testCloningOriginalRefundsExcessivePayment(uint8 gasPrice, uint8 feeBps, uint128 extraFunds) public {
        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: feeBps, feeRecipient: feeRecipientAddress})
        );

        uint256 basefee = _setGasPrice(gasPrice);
        uint256 fee = _calculateCloningFee(original, basefee);
        vm.deal(clonerAddress, fee + extraFunds);

        assertEq(clonerAddress.balance, fee + extraFunds);
        vm.prank(clonerAddress);
        original.clone{value: clonerAddress.balance}(defaultInitdata);
        assertEq(clonerAddress.balance, extraFunds);
    }

    function testCloningCloneRefundsExcessivePayment(uint8 gasPrice, uint8 feeBps, uint128 extraFunds) public {
        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: feeBps, feeRecipient: feeRecipientAddress})
        );
        ClonableContract child = ClonableContract(original.clone(defaultInitdata));

        uint256 basefee = _setGasPrice(gasPrice);
        uint256 fee = _calculateCloningFee(original, basefee);
        vm.deal(clonerAddress, fee + extraFunds);

        assertEq(clonerAddress.balance, fee + extraFunds);
        vm.prank(clonerAddress);
        child.clone{value: clonerAddress.balance}(defaultInitdata);
        assertEq(clonerAddress.balance, extraFunds);
    }

    function testCloningFailsIfRefundFails(uint256 fee) public {
        vm.assume(fee > 0);
        vm.deal(unpayableAddress, fee);

        vm.expectRevert(Clonable.RefundFailed.selector);
        vm.prank(unpayableAddress);
        original.clone{value: fee}(defaultInitdata);
    }

    function testCloningFailsIfPaymentFails(uint8 gasPrice) public {
        vm.assume(gasPrice > 0);

        vm.prank(authorAddress);
        original.updateCloningConfig(
            Clonable.Config({author: authorAddress, feeBps: defaultFeeBps, feeRecipient: unpayableAddress})
        );

        uint256 basefee = _setGasPrice(gasPrice);
        uint256 fee = _calculateCloningFee(original, basefee);
        vm.deal(clonerAddress, fee);

        vm.expectRevert(Clonable.FeeTransferFailed.selector);
        vm.prank(clonerAddress);
        original.clone{value: fee}(defaultInitdata);
    }

    ////////////////
    // Test utils //
    ////////////////

    event Cloned(uint256 fee, address destination);

    receive() external payable {}

    fallback() external payable {}

    function _round(uint256 value, uint256 unit) internal pure returns (uint256) {
        return value / unit * unit;
    }

    function _calculateCloningFee(Clonable clonable, uint256 basefee) internal view returns (uint256) {
        uint256 codesizeDelta = address(clonable).code.length - 45;
        uint256 costSavings = codesizeDelta * 200 * basefee;

        return _round(costSavings * clonable.cloningConfig().feeBps, 1 gwei) / original.CLONING_FEE_BASIS();
    }

    function _setGasPrice(uint8 gasPrice) internal returns (uint256) {
        uint256 basefee = uint256(gasPrice) * 1 gwei;
        vm.fee(basefee);
        return basefee;
    }
}

contract ClonableContract is Clonable {
    error CloneInitError();

    uint256 public someNumber;
    bytes32 public someData;

    constructor(uint256 _someNumber, bytes32 _someData, uint256 _feeBps) Clonable(_feeBps) {
        _initialize(encodeInitdata(_someNumber, _someData));
    }

    function _initialize(bytes memory initdata) internal override {
        (uint256 _someNumber, bytes32 _someData) = abi.decode(initdata, (uint256, bytes32));

        if (_someNumber < 10) revert CloneInitError();

        someNumber = _someNumber;
        someData = _someData;
    }

    function encodeInitdata(uint256 _someNumber, bytes32 _someData) public pure returns (bytes memory) {
        return abi.encode(_someNumber, _someData);
    }

    function decodeInitdata(bytes memory data) public pure returns (uint256, bytes32) {
        return abi.decode(data, (uint256, bytes32));
    }

    function isClone() public view returns (bool) {
        return _isClone();
    }
}

contract Unpayable {
    constructor() {}
}
