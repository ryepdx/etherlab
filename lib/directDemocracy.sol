contract DirectDemocracy is PermissionsProvider, PersistentProtectedContract {
    // PoC-8
    // include "action.sol"

    uint public quorum;
    uint8 public quorumPercent;
    uint public marginForVictory;
    uint8 public marginForVictoryPercent;
    uint public minimumVotingWindow;
    uint public maximumVotingWindow;

    uint VOTING_WINDOW_MIN = 600; // 10 minutes
    bytes32 OWNERS_DB = "OwnersDb";
    bytes32 PERMISSIONS_DB = "PermissionsDb";

    mapping (address => Proposal) public proposals;
    mapping (address => bool) permittedAction;

    enum Vote {
        Null, Yes, No, Abstain
    }

    struct Proposal {
        uint timestamp;
        mapping (address => Vote) votes;
        uint numVotes;
        address proposedAction;
    }

    function DirectDemocracy() {
        quorum = 1;
        quorumPercent = 60;
        marginForVictory = 0;
        marginForVictoryPercent = 0;
    }

    function permitted(address action) returns (bool result) {
        return permittedAction[action];
    }

    function addOwner(address owner) returns (bool added) {
        var dbAddress = ApiProvider(api).contracts(OWNERS_DB);
        if (dbAddress == 0x0 || !permittedSender()) return false;
     
        added = OwnersDb(dbAddress).addOwner(owner);

        if (added) {
            _updateMargins();
        }
    }

    function removeOwner(address owner) returns (bool removed) {
        var dbAddress = ApiProvider(api).contracts(OWNERS_DB);
        var db = OwnersDb(dbAddress);
        var iter = db.owners(owner);

        if (dbAddress == 0x0 || iter == 0x0 || !permittedSender()) {
            return false;
        }

        if (!db.removeOwner(owner)) return false;

        Proposal proposal;
        var numOwners = db.numOwners();

        for (uint i=0; i < numOwners; i+=1) {
            proposal = proposals[iter];
            iter = db.owners(iter);

            if (proposal.proposedAction == 0x0) continue;

            if (proposal.votes[owner] != Vote.Null) { 
                delete proposal.votes[owner];
                proposal.numVotes -= 1;
            }
        }

        delete proposals[owner];
        _updateMargins();

        return true;
    }

    function proposeAction(address proposedAction) {
        var dbAddress = ApiProvider(api).contracts(OWNERS_DB);
        var db = OwnersDb(dbAddress);
        if (db.owners(msg.sender) == 0x0
            || Action(proposedAction).owner() != address(this)) {
            return;
        }
        
        var proposal = proposals[msg.sender];
        proposal.timestamp = block.timestamp;
        proposal.proposedAction = proposedAction;
        proposal.votes[msg.sender] = Vote.Yes;
        proposal.numVotes = 1;
    }

    function withdrawProposedAction() {
        _removeProposal(msg.sender);
    }

    function setQuorumPercent(uint8 percent) {
        if (!permittedSender()) return;
        quorumPercent = percent;
        _updateMargins();
    }

    function setMarginForVictoryPercent(uint8 percent) {
        if (!permittedSender()) return;
        marginForVictoryPercent = percent;
        _updateMargins();
    }

    function setMinimumVotingWindow(uint minimumWindow) {
        if (!permittedSender()) return;
        minimumVotingWindow = minimumWindow;
    }

    function setMaximumVotingWindow(uint maximumWindow) {
        if ((maximumWindow < VOTING_WINDOW_MIN && maximumWindow != 0)
            || !permittedSender()) {
            return;
        }
        maximumVotingWindow = maximumWindow;
    }

    function wipeProposedActions() {
        if (!permittedSender()) return;

        var dbAddress = ApiProvider(api).contracts(OWNERS_DB);
        var db = OwnersDb(dbAddress);
        var iter = db.ownersTail();
        var numOwners = db.numOwners();

        for (uint i=0; i < numOwners; i += 1) {
            if (proposals[iter].proposedAction != 0x0) {
                Action(proposals[iter].proposedAction).remove();
                delete proposals[iter];
            }
            iter = db.owners(iter);
        }
    }

    function vote(address owner, address action, Vote vote) {
        // We require the action parameter to make sure the voter knows
        // exactly what they are voting on, to prevent "bait & switch."
        var proposal = proposals[owner];

        if (action == 0x0
            || proposal.proposedAction != action
            || vote == Vote.Null) {
            return;
        }        

        if (maximumVotingWindow == 0
            || block.timestamp <= (proposal.timestamp + maximumVotingWindow)) {

            if (proposal.votes[msg.sender] == Vote.Null) {
                proposal.numVotes += 1;
            }

            proposal.votes[msg.sender] = vote;
        }

        if (block.timestamp > (proposal.timestamp + minimumVotingWindow)) {
            var outcome = _checkVotes(owner);
 
            if (outcome == Vote.Null) return;

            if (outcome == Vote.Yes) {
                permittedAction[proposal.proposedAction] = true;
                Action(proposal.proposedAction).execute();
                delete permittedAction[proposal.proposedAction];
            }
            _removeProposal(owner);
        }
    }

    function spend(address recipient, uint amount) {
        if (!permittedSender()) return;
        recipient.send(amount);
    }

    function remove() {
        if (!permittedSender()) return;
        super.remove();
    }

    function _removeProposal(address owner) private {
        if (proposals[owner].proposedAction == 0x0) return;
        delete proposals[owner];
    }

    function _updateMargins() private {
        var numOwners = OwnersDb(ApiProvider(api).contracts(OWNERS_DB)).numOwners();
        quorum = (numOwners * 100) / quorumPercent;
        marginForVictory = (numOwners * 100) / marginForVictoryPercent;
    }

    function _checkVotes(address owner) private returns (Vote result) {
        var proposal = proposals[owner];
        if (proposal.numVotes < quorum) {
            return Vote.Null;
        }

        uint yesTally = 0;
        uint noTally = 0;
        var db = OwnersDb(ApiProvider(api).contracts(OWNERS_DB));
        var numOwners = db.numOwners();
        var iter = db.ownersTail();
        
        for (uint i=0; i < numOwners; i+=1) {
            iter = db.owners(iter);

            if (proposal.votes[iter] == Vote.Abstain || proposal.votes[iter] == Vote.Null) {
                continue;
            }

            if (proposal.votes[iter] == Vote.Yes) {
                yesTally += 1;
            } else {
                noTally -= 1;
            }
        }

        if (noTally > yesTally && (noTally - yesTally) >= marginForVictory) {
            return Vote.No;

        } else if (yesTally > noTally && (yesTally - noTally) >= marginForVictory) {
            return Vote.Yes;
        }

        return Vote.Null;
    }
}
