// SPDX-License-Identifier: GPL-3.0

pragma solidity ^ 0.8.11;
contract Wallet {
    // --------------------------------Variables--------------------------------
    address private admin;
    uint96 public quorum;
    uint currentId;
    uint owners;
    mapping(address => bool) addressToOwner;
    mapping(address => mapping(uint => bool)) private approvals;
    mapping(uint256 => proposal) public Proposals;
    enum purpose { Deposit, Withdraw }

    // --------------------------------Structs--------------------------------
    struct proposal {
    uint amount;
    uint96 id;
    address initiator;
    uint88 approver;
    bool finished;
    address payable to;
    purpose choice;
    }

    // --------------------------------Events --------------------------------
    event singleOwnwerAdded(address addr);
    event singleOwnerRemoved(address addr);
    event multipleOwnerAdded (address[] addrs);
    event transactionInitiated(uint256 proposalId, uint256 amount, purpose choice);
    event quorumMet(bool _quorumMet);
    event proposalExecuted(address initiator, uint256 amount, uint256 quorum, purpose choice);

    // --------------------------------Errors--------------------------------
    error notAuthorized();
    error ownerExistsAlready(address _addr);
    error canOnlyApproveOnce();
    error quorumNotmet();
    error proposalAlreadyExecuted();
    error insufficientFunds();
    error wrongAmountTransferred();
    error invalidQuorum();
    error ownerDoesNotExist(address _addr);
    error transactionNotYetInitiated();
    error invalidAddress();
    error transactionFailed();


    // --------------------------------Constructor--------------------------------
    constructor (address _admin) {
        admin =_admin;
        quorum = 60; 
    }

    // --------------------------------Modifiers--------------------------------

    //modifier to ensure only added woners can all any funcion it's attached to
    modifier onlyOwners () {
         if (!addressToOwner[msg.sender]) revert notAuthorized();
        _;
    }

    // modifier to ensure only the admin can call any functions it is attached to
    modifier onlyAdmin {
        if (msg.sender != admin) revert notAuthorized();
        _;
    }
    // modifier to check if transaction has been initiated already before owners add their  approvals
     modifier checkTransactionInitiated(uint _id){
        if (Proposals[_id].initiator == address(0x0)) revert transactionNotYetInitiated();
        _;
    }

    // --------------------------------Functions--------------------------------

    // this external function allows the admin to set a new quorum 
    // _quorum should be entered with its in percentage i.e 0-100
    function setQuorum (uint _quorum) onlyAdmin external {
        if (_quorum > 100 || _quorum < 0) revert invalidQuorum();
        quorum = uint96(_quorum);
    } 
    
    // this external function allows the admin to add an address as a owner in the owners address list
    function addSingleOwner (address _addr) onlyAdmin external {
        if (_addr == address(0x0)) revert invalidAddress();
        bool ownerExisist = checkOwnerExists(_addr);
        if (ownerExisist) revert ownerExistsAlready(_addr);
        addressToOwner[_addr] = true;
        owners++;
        emit singleOwnwerAdded(_addr);
    } 

    // this external function allows the admin to add  multiple addresses as  owners in the owners address list
    function addMultipleOwner (address[] calldata _addresses) onlyAdmin external {
         for (uint256 i ; i < _addresses.length; i++) {
             if (_addresses[i] == address(0x0)) revert invalidAddress();
              bool ownerExisist = checkOwnerExists(_addresses[i]);
           if (ownerExisist) revert ownerExistsAlready(_addresses[i]);
            addressToOwner[_addresses[i]] = true;
            owners++;
        }
        emit multipleOwnerAdded(_addresses);
    }

    // this external function allows the admin to remove an address as an owner, one at a time.
     function removeSingleOwner (address _addr) onlyAdmin external {
        bool ownerExisist = checkOwnerExists(_addr);
        if (!ownerExisist) revert ownerDoesNotExist(_addr);
        addressToOwner[_addr] = false;
        owners--;
        emit singleOwnerRemoved(_addr);
    } 

    function removeMultipleOwners (address[] calldata _addresses) onlyAdmin external {
         for (uint256 i ; i < _addresses.length; i++) {
             if (_addresses[i] == address(0x0)) revert invalidAddress();
              bool ownerExisist = checkOwnerExists(_addresses[i]);
           if (!ownerExisist) revert ownerDoesNotExist(_addresses[i]);
            addressToOwner[_addresses[i]] = false;
            owners--;
        }
        emit multipleOwnerAdded(_addresses);
    }
    // this internal function checks to see if an address is already in the owners address array
    function checkOwnerExists (address _addr) view public returns(bool ownerExists) {
       return addressToOwner[_addr];
    }

    // this external function uses the Id passed to fetch its coresponding proposal and allows owners approve it.
    function approveTransactionProposal (uint256 _id) external onlyOwners() checkTransactionInitiated(_id) {
        if (approvals[msg.sender][_id]) revert canOnlyApproveOnce();
        proposal storage o = Proposals[_id];
        o.approver++;
        approvals[msg.sender][_id] = true;
        if (checkIfQourumMet(_id)) emit quorumMet(true);
        else emit quorumMet(false);
    }

    // this external function allows an owner to initiate a transaction by passing the amount and transaction enum type( 0 || 1 )
    function initiaiteTransactionProposal (uint256 _amount, purpose _choice, address _to)  external onlyOwners {
        currentId++;
        proposal storage o = Proposals[currentId];
        o.initiator = msg.sender;
        o.id = uint96(currentId);
        o.amount = _amount;
        o.to = payable(_to);
        o.approver++;
        o.choice = _choice;
        approvals[msg.sender][currentId] = true;
        emit transactionInitiated({
            proposalId: o.id,
            amount: _amount,
            choice: o.choice
            });
    }

    // internal function to check if the quorum for a particular proposal has been met
    function checkIfQourumMet(uint256 _id) internal view returns(bool _quorumMet){
        proposal storage o = Proposals[_id];
        uint256 approvers = uint256(o.approver) * 100;
        uint minApprovers = quorum * owners;
        if (approvers >= minApprovers) _quorumMet = true;
        else  _quorumMet = false;
        return _quorumMet;
    }

    // external function to aallow the proposal initializer execute the proposal after quorum has been met
    function executeProposal (uint256 _id) checkTransactionInitiated(_id) external payable {
        proposal storage o = Proposals[_id];
        if (o.initiator != msg.sender) revert notAuthorized();
        if (o.finished) revert proposalAlreadyExecuted();
        if (!checkIfQourumMet(_id)) revert quorumNotmet();
        if(o.choice == purpose.Deposit){
            if (msg.value != o.amount) revert wrongAmountTransferred();
        } else if (o.choice == purpose.Withdraw){
            uint256 contractBalance = address(this).balance;
            if (contractBalance < o.amount) revert insufficientFunds();
            payable(o.to).transfer(o.amount);
            // if (!success) revert transactionFailed();
        }
        o.finished = true;
        emit proposalExecuted ({
            initiator : o.initiator,
            amount: o.amount,
            quorum: o.approver,
            choice: o.choice
        });
    }
    receive() external payable {}
}
