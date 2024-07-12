// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SmartWallet is Initializable, OwnableUpgradeable {
    //enum for store the status of withdrawn request
    enum WithdrawnStatus {
        Pending,
        Rejected,
        Approved,
        Completed
    }

    //structure to store the withdrawn requests details
    struct WithdrawlRequest {
        uint256 requestId;
        address payable requestOwnerAddress;
        address payable firstSinger;
        address payable secondSinger;
        uint256 withdrawalAmount;
        WithdrawnStatus requestStatus;
    }

    //structure to store the deposit amount details
    struct DepositAmount {
        address payable sender;
        uint256 depositedAmount;
    }

    //structure to store the proccess request details
    struct ProccessRequest {
        bool isProcessed;
        uint256 requestId;
        address sender;
    }

    //structure to store the signature details
    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    //contracts events
    event AmountDeposited(address indexed sender, uint256 amount);
    event RequestWithdrawl(uint256 indexed requestId, address requestOwner);
    event RequestApproved(
        uint256 indexed requestId,
        address firstSinger,
        address secondSinger,
        WithdrawnStatus requestStatus
    );
    event SignersUpdated(address firstAdminAddress, address secondAdminAddress);

    //state variables
    uint256 private _requestIds;

    //mapping
    mapping(uint256 => address) private _admins;
    mapping(uint256 => WithdrawlRequest) private _withdrawlRequests;
    mapping(address => DepositAmount) private _depositAmounts;
    mapping(address => ProccessRequest) private _requestProccess;

    // modifier
    modifier onlyAdmins() {
        require(
            _admins[1] == msg.sender || _admins[2] == msg.sender,
            "caller is not the an admin"
        );
        _;
    }

    function initialize(address _firstAdminAddress, address _secondAdminAddress)
        public
        initializer
    {
        __Ownable_init(msg.sender);
        require(
            _firstAdminAddress != address(0) &&
                _secondAdminAddress != address(0),
            "signers should not be zero"
        );
        _admins[1] = _firstAdminAddress;
        _admins[2] = _secondAdminAddress;
        // owner = msg.sender;
    }

    /*** 
        @notice deposite funds
        @param amount The amount to deposit
    **/
    function depositFunds(uint256 amount) public payable {
        require(amount > 0 && amount == msg.value, "amount is not valid");
        if (_depositAmounts[msg.sender].sender != address(0)) {
            _depositAmounts[msg.sender].depositedAmount += amount;
        } else {
            _depositAmounts[msg.sender] = DepositAmount(
                payable(msg.sender),
                amount
            );
        }

        emit AmountDeposited(msg.sender, amount);
    }

    /*** 
        @notice withdraw request
        @param withdrawalAmount The amount to withdraw
        @param payloadHash The  payload hash sign by sender
        @param signature The signature of sender

    **/
    function requestForWithdraw(
        uint256 withdrawalAmount,
        bytes32 payloadHash,
        Signature memory signature
    ) public {
        // Verify the signature
        address signer = verifySignature(payloadHash, signature);
        require(signer == msg.sender, "invalid signer");

        require(
            address(this).balance > 0 &&
                address(this).balance >= withdrawalAmount,
            "Contract balance is zero or not enough"
        );
        require(
            _depositAmounts[msg.sender].depositedAmount > 0 &&
                _depositAmounts[msg.sender].depositedAmount >= withdrawalAmount,
            "You dont't have enough balacne"
        );
        require(
            _requestProccess[msg.sender].isProcessed == true ||
                (_requestProccess[msg.sender].isProcessed == false &&
                    _requestProccess[msg.sender].sender == address(0)),
            "Your last request is not completed yet"
        );

        _incrementRequestId();
        uint256 _requestId = _requestIds;
        _withdrawlRequests[_requestId] = WithdrawlRequest(
            _requestId,
            payable(msg.sender),
            payable(msg.sender),
            payable(address(0)),
            withdrawalAmount,
            WithdrawnStatus(0)
        );

        _requestProccess[msg.sender] = ProccessRequest(
            false,
            _requestId,
            msg.sender
        );

        emit RequestWithdrawl(_requestId, msg.sender);
    }

    /*** 
        @noticesiging withdraw request
        @param withdrawalAmount The amount to withdraw
        @param payloadHash The  payload hash sign by sender
        @param signature The signature of sender

    **/
    function signWithdrawlRequest(
        address requestOwner,
        bytes32 payloadHash,
        Signature memory signature
    ) public payable onlyAdmins {
        require(
            _requestIds != 0 && requestOwner != address(0),
            "invalid payload"
        );
        // Verify the signature
        address signer = verifySignature(payloadHash, signature);
        require(signer == msg.sender, "invalid signer");

        require(
            _requestProccess[requestOwner].isProcessed == false &&
                _requestProccess[requestOwner].sender == requestOwner,
            "Your last request is not completed yet"
        );
        uint256 requestId = _requestProccess[requestOwner].requestId;
        require(
            _withdrawlRequests[requestId].requestOwnerAddress != msg.sender,
            "The owner can not sign for this request"
        );
        require(
            _withdrawlRequests[requestId].firstSinger != msg.sender,
            "Could not sign your request again"
        );
        require(
            _withdrawlRequests[requestId].secondSinger == address(0),
            "The signing for this request is already completed"
        );
        require(
            _withdrawlRequests[requestId].requestStatus == WithdrawnStatus(0),
            "The request is already approved"
        );

        _withdrawlRequests[requestId].secondSinger = payable(msg.sender);
        _withdrawlRequests[requestId].requestStatus = WithdrawnStatus(2);

        // transfer amount to user
        uint256 withdrawalAmount = _withdrawlRequests[requestId]
            .withdrawalAmount;
        require(withdrawalAmount > 0, "No amount to withdraw");
        payable(requestOwner).transfer(withdrawalAmount);

        _requestProccess[requestOwner].isProcessed = true;
        _depositAmounts[requestOwner].depositedAmount -= withdrawalAmount;

        emit RequestApproved(
            requestId,
            _withdrawlRequests[requestId].firstSinger,
            _withdrawlRequests[requestId].secondSinger,
            WithdrawnStatus(2)
        );
    }

    /*** 
        @noticesiging update Signers
        @param _firstAdminAddress The first signer who can approve the transaction
        @param _secondAdminAddress The second signer who can approve the transaction
    **/
    function updateSigners(
        address _firstAdminAddress,
        address _secondAdminAddress
    ) public onlyOwner {
        require(
            _firstAdminAddress != address(0) &&
                _secondAdminAddress != address(0),
            "signers should not be zero"
        );
        _admins[1] = _firstAdminAddress;
        _admins[2] = _secondAdminAddress;

        emit SignersUpdated(_firstAdminAddress, _secondAdminAddress);
    }

    /***
        internal methods
    **/
    function _incrementRequestId() internal {
        _requestIds++;
    }

    function verifySignature(bytes32 payloadHash, Signature memory signature)
        internal
        pure
        returns (address)
    {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, payloadHash));
        address signer = ecrecover(
            prefixedHash,
            signature.v,
            signature.r,
            signature.s
        );
        return signer;
    }

    //fallback function
    fallback() external payable {}

    // receive function
    receive() external payable {}

    /***
        getter methods
    **/

    // function to get singers
    function getSigners()
        public
        view
        onlyOwner
        returns (address firstSinger, address secondSinger)
    {
        firstSinger = _admins[1];
        secondSinger = _admins[2];
        return (firstSinger, secondSinger);
    }

    // function to get user balance
    function getUserBalance(address ownerAddress)
        public
        view
        returns (uint256 balance)
    {
        require(ownerAddress != address(0), "address should not be zero");
        balance = _depositAmounts[msg.sender].depositedAmount;
        return balance;
    }

    //funtion to get the withdral request status for given requestId
    function getWithdralRequestStatus(uint256 requestId_)
        public
        view
        onlyAdmins
        returns (WithdrawnStatus)
    {
        return _withdrawlRequests[requestId_].requestStatus;
    }

    //method to get the requestId
    function getCurrentRequestId() public view returns (uint256) {
        return _requestIds;
    }

    //funtion to get the contract balance
    function getContractBalance() public view returns (uint256) {
        return (address(this)).balance;
    }
}
