contract root {
    // PoC-8

    uint public currentVersion;
    mapping (uint => address) public api;
    mapping (address => address) public owners;
    address _ownersTail;
    uint _numOwners;
    uint public quorum;
    uint8 public quorumPercent;
    uint public marginForVictory;
    uint8 public marginForVictoryPercent;
    mapping (address => ProposalCollection) public proposals;
 
    enum ProposalType {
        AddOwner, RemoveOwner,
        SetQuorumPercent, SetMarginForVictoryPercent,
        SetContract, SetVersion, SetApi, WipeProposals,
        Spend
    }

    enum Vote {
        Null, Yes, No, Abstain
    }

    struct ProposalCollection {
        mapping (uint => Proposal) proposals;
        mapping (uint => uint) timestamps;
        uint timestampsTail;
        uint8 numProposals;
    }

    struct Proposal {
        mapping (address => Vote) votes;
        uint numVotes;
        ProposalType type;
        address targetAddress;
        string32 targetFunction;
        address proposedContract;
        uint8 proposedPercent;
        uint value;
    }

    function root() {
        quorum = 1;
        quorumPercent = 60;
        marginForVictory = 0;
        owners[msg.sender] = msg.sender;
        _ownersTail = msg.sender;
    }

    function withdrawProposal(uint timestamp) {
        _removeProposal(msg.sender, timestamp);
    }

    function addOwner(address proposedOwner) {
        _createProposal(msg.sender, ProposalType.AddOwner);
        proposals[msg.sender].proposals[block.timestamp].targetAddress = proposedOwner;
    }

    function removeOwner(address proposedOwner) {
        _createProposal(msg.sender, ProposalType.RemoveOwner);
        proposals[msg.sender].proposals[block.timestamp].targetAddress = proposedOwner;
    }

    function setQuorumPercent(uint8 proposedQuorum) {
        _createProposal(msg.sender, ProposalType.SetQuorumPercent);
        proposals[msg.sender].proposals[block.timestamp].proposedPercent = proposedQuorum;
    }

    function setMarginForVictoryPercent(uint8 proposedMargin) {
        _createProposal(msg.sender, ProposalType.SetMarginForVictoryPercent);
        proposals[msg.sender].proposals[block.timestamp].proposedPercent = proposedMargin;
    }

    function setContract(address targetContract, string32 targetFunction, address proposedContract) {
        _createProposal(msg.sender, ProposalType.SetContract);
        var proposal = proposals[msg.sender].proposals[block.timestamp];
        proposal.targetAddress = targetContract;
        proposal.targetFunction = targetFunction;
        proposal.proposedContract = proposedContract;
    }

    function setVersion(uint version) {
        _createProposal(msg.sender, ProposalType.SetVersion);
        proposals[msg.sender].proposals[block.timestamp].value = version;
    }

    function setApi(uint version, address proposedApi) {
        _createProposal(msg.sender, ProposalType.SetVersion);
        var proposal = proposals[msg.sender].proposals[block.timestamp];
        proposal.value = version;
        proposal.proposedContract = proposedApi;
    }

    function wipeProposals() {
        _createProposal(msg.sender, ProposalType.WipeProposals);
    }

    function vote(address owner, uint timestamp, Vote vote) {
        if (proposals[owner].numProposals == 0 || proposals[owner].timestamps[timestamp] == 0) return;
        
        proposals[owner].proposals[timestamp].votes[msg.sender] = vote;
        proposals[owner].proposals[timestamp].numVotes += 1;

        _checkVotes(owner, timestamp);
    }

    function execute(address owner, uint timestamp) {
        if (proposals[owner].numProposals == 0 || proposals[owner].timestamps[timestamp] == 0) return;
        _checkVotes(owner, timestamp);
    }

    function _removeProposal(address owner, uint timestamp) private {
        var collection = proposals[owner];
        if (collection.numProposals == 0 || collection.timestamps[timestamp] == 0) return;

        uint iter = timestamp;
        for (uint8 i=0; i < collection.numProposals-1; i += 1) {
            iter = collection.timestamps[iter];
        }
        collection.timestamps[iter] = collection.timestamps[timestamp];

        delete collection.proposals[timestamp];
        collection.numProposals -= 1;
    }

    function _addOwner(address owner) private {
        owners[owner] = owners[_ownersTail];
        owners[_ownersTail] = owner;
        _ownersTail = owner;
        _numOwners += 1;
        proposals[owner].numProposals = 0;

        _updateMargins();
    }

    function _removeOwner(address owner) private {
        if (owners[owner] == address(0)) return;

        uint timestamp;
        address iter = owner;

        for (uint i=0; i < _numOwners-1; i+=1) {
            iter = owners[iter];
            
            var collection = proposals[iter];

            if (collection.numProposals == 0) continue;

            timestamp = collection.timestampsTail;

            for (uint8 j=0; j < collection.numProposals; j+=1) {
                if (collection.proposals[timestamp].votes[owner] != Vote.Null) {
                    delete collection.proposals[timestamp].votes[owner];
                    collection.proposals[timestamp].numVotes -= 1;
                }
                timestamp = collection.timestamps[timestamp];
            }
        }

        owners[iter] = owners[owner];
        delete owners[owner];
        delete proposals[owner];
        _numOwners -= 1;

        _updateMargins();
    }

    function _setQuorumPercent(uint8 percent) private {
        quorumPercent = percent;
        _updateMargins();
    }

    function _setMarginForVictoryPercent(uint8 percent) private {
        marginForVictoryPercent = percent;
        _updateMargins();
    }

    function _setContract(address targetContract, string32 targetFunction, address newContract) private {
        targetContract.call(string4(string32(sha3("setFunction(string32, address)"))), targetFunction, newContract);
    }

    function _setVersion(uint version) private {
        currentVersion = version;
    }

    function _setApi(uint version, address proposedApi) private {
        api[version] = proposedApi;
    }

    function _wipeProposals() private {
        address iter = _ownersTail;
        for (uint i=0; i < _numOwners; i += 1) {
            delete proposals[iter];
        }
        iter = owners[iter];
    }

    function _spend(address recipient, uint amount) private {
        recipient.send(amount);
    }

    function _updateMargins() private {
        quorum = (_numOwners * 100) / quorumPercent;
        marginForVictory = (_numOwners * 100) / marginForVictoryPercent;
    }

    function _createProposal(address owner, ProposalType type) internal {
        var collection = proposals[owner];

        if (collection.numProposals == 0) {
            collection.timestampsTail = block.timestamp;
            collection.timestamps[block.timestamp] = block.timestamp;

        } else {
            collection.timestamps[block.timestamp] = collection.timestamps[collection.timestampsTail];
            collection.timestamps[collection.timestampsTail] = block.timestamp;
            collection.timestampsTail = block.timestamp;
        }
        collection.numProposals += 1;

        var proposal = collection.proposals[block.timestamp];
        proposal.type = type;
        proposal.numVotes = 1;
        proposal.votes[owner] = Vote.Yes;
    }

    function _checkVotes(address owner, uint timestamp) private {
        var proposal = proposals[owner].proposals[timestamp];

        if (proposal.numVotes < quorum) return;

        uint yesTally = 0;
        uint noTally = 0;
        address iter = _ownersTail;
        
        for (uint i=0; i < _numOwners; i+=1) {
            if (proposal.votes[iter] == Vote.Abstain || proposal.votes[iter] == Vote.Null) {
                 continue;
            }

            if (proposal.votes[iter] == Vote.Yes) {
                yesTally += 1;
            } else {
                noTally -= 1;
            }
        }

        if (yesTally > noTally && (yesTally - noTally) >= marginForVictory) {
            _execute(owner, timestamp);
        } else if (noTally > yesTally && (noTally - yesTally) >= marginForVictory) {
            _removeProposal(owner, timestamp);
        }
    }

    function _execute(address owner, uint timestamp) private {
        var proposal = proposals[owner].proposals[timestamp];

        if (proposal.type == ProposalType.AddOwner) {
            _addOwner(proposal.targetAddress);

        } else if (proposal.type == ProposalType.RemoveOwner) {
            _removeOwner(proposal.targetAddress);

        } else if (proposal.type == ProposalType.SetQuorumPercent) {
            _setQuorumPercent(proposal.proposedPercent);

        } else if (proposal.type == ProposalType.SetMarginForVictoryPercent) {
            _setQuorumPercent(proposal.proposedPercent);

        } else if (proposal.type == ProposalType.SetContract) {
            _setContract(proposal.targetAddress, proposal.targetFunction,
                              proposal.proposedContract);

        } else if (proposal.type == ProposalType.SetVersion) {
            _setVersion(proposal.value);

        } else if (proposal.type == ProposalType.SetApi) {
            _setApi(proposal.value, proposal.proposedContract);

        } else if (proposal.type == ProposalType.WipeProposals) {
            _wipeProposals();

        } else if (proposal.type == ProposalType.Spend) {
            _spend(proposal.targetAddress, proposal.value);
        } 
        _removeProposal(owner, timestamp);
    }
}
