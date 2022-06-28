// SPDX-License-Identifier: GPL-3.0

pragma solidity ^ 0.8.11;
contract Wallet {
    // --------------------------------Variables--------------------------------
    address private admin;
    uint96 public quorum;
    uint currentId;
    address[] public owners;
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
    error notAdmin();
    error notOwner();
    error ownerExistsAlready(address _addr);
    error canOnlyApproveOnce();
    error quorumNotmet();
    error notProposalInitiator();
    error proposalAlreadyExecuted();
    error insufficientFunds();
    error wrongAmountTransferred();
    error invalidQuorum();
    error ownerDoesNotexist(address _addr);


    // --------------------------------Constructor--------------------------------
    constructor (address _admin) {
        admin =_admin;
        quorum = 60; 
    }

    // --------------------------------Modifiers--------------------------------
    modifier onlyOwners () {
        bool allowed = false;
        for (uint256 i; i<owners.length; i++) {
            if (owners[i] == msg.sender) {
                allowed = true;
            }
        }
         if (!allowed) revert notOwner();
        _;
    }

    modifier onlyAdmin {
        if (msg.sender != admin) revert notAdmin();
        _;
    }

    // --------------------------------Functions--------------------------------

    // _quorum should be entered with its in percentage
    function setQuorum (uint _quorum) onlyAdmin external {
        if (_quorum > 100 || _quorum < 0) revert invalidQuorum();
        quorum = uint32(_quorum);
    } 
    
    function addSingleOwner (address _addr) onlyAdmin external {
        bool ownerExisist = checkOwnerExists(_addr);
        if (ownerExisist) revert ownerExistsAlready(_addr);
        owners.push(_addr);
        emit singleOwnwerAdded(_addr);
    } 

    function addMultipleOwner (address[] calldata _addresses) onlyAdmin external {
         for (uint256 i ; i < _addresses.length; i++) {
              bool ownerExisist = checkOwnerExists(_addresses[i]);
           if (ownerExisist) revert ownerExistsAlready(_addresses[i]);
           owners.push(_addresses[i]);
        }
        emit multipleOwnerAdded(_addresses);
    }

     function removeSingleOwner (address _addr) onlyAdmin external {
        bool ownerExisist = checkOwnerExists(_addr);
        if (!ownerExisist) revert ownerDoesNotexist(_addr);
        address ownerToCompare = owners[owners.length-1];
        for(uint i = 0; i < owners.length; i++){
            if (owners[i] == _addr){
                owners[i] = ownerToCompare; 
            }
        }
        owners.pop();
        emit singleOwnerRemoved(_addr);
    } 
    // This is an expensive operation. Might be removed

    function checkOwnerExists (address _addr) view public returns(bool ownerExists) {
         bool matches;
        for (uint256 i ; i < owners.length; i++) {
            if (owners[i] == _addr) {
                matches = true;
                ownerExists = true;
                break;
            }
        }
        if (!matches) {
            ownerExists = false;
        }
    }

    function approveTransactionProposal (uint256 _id) external onlyOwners {
        if (approvals[msg.sender][_id]) revert canOnlyApproveOnce();
        proposal storage o = Proposals[_id];
        o.approver++;
        approvals[msg.sender][_id] = true;
        if (checkIfQourumMet(_id)) emit quorumMet(true);
        else emit quorumMet(false);
    }

    function initiaiteTransactionProposal (uint256 _amount, purpose _choice)  external onlyOwners {
        currentId++;
        proposal storage o = Proposals[currentId];
        o.initiator = msg.sender;
        o.id = uint96(currentId);
        o.amount = _amount;
        o.to = payable(address(this));
        o.approver++;
        o.choice = _choice;
        approvals[msg.sender][currentId] = true;
        emit transactionInitiated({
            proposalId: o.id,
            amount: _amount,
            choice: o.choice
            });
    }

    function checkIfQourumMet(uint256 _id) internal view returns(bool _quorumMet){
        proposal storage o = Proposals[_id];
        uint256 approvers = uint256(o.approver) * 100;
        uint minApprovers = quorum * owners.length;
        if (approvers >= minApprovers) _quorumMet = true;
        else  _quorumMet = false;
        return _quorumMet;
    }

    function executeProposal (uint256 _id) external payable {
        proposal storage o = Proposals[_id];
        if (o.initiator != msg.sender) revert notProposalInitiator();
        if (o.finished) revert proposalAlreadyExecuted();
        if (!checkIfQourumMet(_id)) revert quorumNotmet();
        if(o.choice == purpose.Deposit){
            if (msg.value != o.amount) revert wrongAmountTransferred();
        } else if (o.choice == purpose.Withdraw){
            uint256 contractBalance = address(this).balance;
            if (contractBalance < o.amount) revert insufficientFunds();
            payable(o.to).transfer(o.amount);
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
