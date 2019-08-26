pragma solidity >= 0.5.0;

contract Owned {
    address payable public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only owner can execute this method.");
        _;
    }

    function transferOwnership(address payable newOwner) public onlyOwner {
        owner = newOwner;
    }
}
