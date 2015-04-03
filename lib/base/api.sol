contract ApiProvider {
    function contracts(bytes32 name) returns (address addr) {}
    function addContract(bytes32, address newContract) returns (bool result) {}
    function removeContract(bytes32) returns (bool result) {}
}

contract ApiEnabled {
    function apiAuthorized() returns (bool result) {}
    function setApiAddress(address newApi) returns (bool result) {}
    function remove() {}
}
