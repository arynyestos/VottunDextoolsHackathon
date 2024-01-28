// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface DocTokenContract {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}

interface MocProxyContract {
    function redeemDocRequest (uint256 docAmount) external;
    function redeemFreeDoc(uint256 docAmount) external;
}

contract DCAContract {
    address public docTokenAddress = 0xCB46c0ddc60D18eFEB0E586C17Af6ea36452Dae0; // Address of the DOC token contract in Rootstock testnet
    address public mocProxyAddress = 0x2820f6d4D199B8D8838A4B26F9917754B86a0c1F; // Address of the MoC proxy contract in Rootstock testnet
    address public immutable i_owner; // Address of the contract owner

    DocTokenContract docTokenContract = DocTokenContract(docTokenAddress);
    MocProxyContract mocProxyContract = MocProxyContract(mocProxyAddress);

    mapping(address user => uint256 docBalance) public docBalances; // DOC balances deposited by users
    mapping(address user => uint256 purchaseAmount) public docPurchaseAmounts; // DOC balances deposited by users
    mapping(address user => uint256 accumulatedBtc) public rbtcBalances; // Accumulated RBTC balance of users

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RbtcBought(address indexed user, address rBtcSenderContract, uint256 rbtcAmount);
    event WithdrawnBTC(address indexed user, uint256 rbtcAmount);


    constructor() {
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == i_owner, "Not the contract owner");
        _;
    }

    modifier onlyMocProxy() {
        require(msg.sender == mocProxyAddress, "Only MoC proxy can send rBTC to DCA contract");
        _;
    }
    
    function depositDOC(uint256 depositAmount) external {
        require(depositAmount > 0, "Amount must be greater than zero");

        // Transfer DOC from the user to this contract, user must have called the DOC contract's 
        // approve function with this contract's address and the amount approved
        bool success = docTokenContract.transferFrom(msg.sender, address(this), depositAmount);
        require(success, "Transfer failed");

        // Update user's DOC balance in the mapping
        docBalances[msg.sender] += depositAmount;

        emit Deposited(msg.sender, depositAmount);
    }

    function withdrawDOC(uint256 withdrawalAmount) external {
        require(withdrawalAmount > 0, "Amount must be greater than zero");
        require(withdrawalAmount <= docBalances[msg.sender], "Insufficient DOC balance");

        // Transfer DOC from this contract back to the user
        bool withdrawSuccess = docTokenContract.transfer(msg.sender, withdrawalAmount);
        require(withdrawSuccess, "Transfer failed");
        

        // Update user's DOC balance in the mapping
        docBalances[msg.sender] -= withdrawalAmount;

        emit Withdrawn(msg.sender, withdrawalAmount);
    }

    function setPurchaseAmount(uint256 purchaseAmount) external {
        require(purchaseAmount > 0, "Amount must be greater than zero");
        require(purchaseAmount < docBalances[msg.sender] / 2, "Purchase amount must be lower than half of deposited amount.");
        docPurchaseAmounts[msg.sender] = purchaseAmount;
    }

    function buy(address buyer) external onlyOwner {
        // Redeem DOC for rBTC
        (bool success, bytes memory result) = mocProxyAddress.call(abi.encodeWithSignature("redeemDocRequest(uint256)", docPurchaseAmounts[buyer]));

        require(success, "redeemDocRequest failed");

        uint256 balancePrev = address(this).balance;

        // Now that redeemDocRequest has completed, proceed to redeemFreeDoc
        (success, result) = mocProxyAddress.call(abi.encodeWithSignature("redeemFreeDoc(uint256)", docPurchaseAmounts[buyer]));

        require(success, "redeemFreeDoc failed");

        uint256 balancePost = address(this).balance;
        
        rbtcBalances[buyer] += (balancePost - balancePrev);

        // Emit event
        //emit Bought(msg.sender, docAmountToRedeem, rbtcAmount);
    }

    function withdrawAccumulatedRbtc() external {

        // Transfer RBTC from this contract back to the user
        (bool sent, ) = msg.sender.call{value: rbtcBalances[msg.sender]}("");
        require(sent, "Failed to withdraw rBTC");

        // Update user's RBTC balance in the mapping
        rbtcBalances[msg.sender] -= rbtcBalances[msg.sender];

        emit WithdrawnBTC(msg.sender, rbtcBalances[msg.sender]);
    }

    function getDocBalance() external view returns (uint256) {
        return docBalances[msg.sender];
    }

    function getRbtcBalance() external view returns (uint256) {
        return rbtcBalances[msg.sender];
    }

    function getPurchaseAmount() external view returns (uint256) {
        return docPurchaseAmounts[msg.sender];
    }

    receive() external payable onlyMocProxy {}

}
