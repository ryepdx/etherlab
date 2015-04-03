contract Action is Owned {
    // PoC-8
    // include "owned.sol"

    // This is the interface required for smart contracts
    // submitted via proposeAction.

    function execute() {
        if (msg.sender != owner) return;
        _execute();
    }

    function remove() {
        if (msg.sender != owner) return;
        suicide(owner);
    }

    function _execute() private {
        // Override this in your extending class with your own code.
    }
}
