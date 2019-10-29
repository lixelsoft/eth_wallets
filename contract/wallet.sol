pragma solidity ^0.4.25;


contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
      * @dev The Ownable constructor sets the original `owner` of the contract to the sender
      * account.
    */
    constructor() public {
        owner = msg.sender;
    }

    /**
      * @dev Throws if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "sender is not owner");
        _;
    }

    /**
      * @dev Allows the current owner to transfer control of the contract to a newOwner.
      * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "newOwner addres is zero");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

interface IWallet {
    function deposit(address sender, address receiver, uint256 amount) public view;
}

/**
 * Contract that will forward any incoming Ether to the creator of the contract
 */
contract Child {

    // Address to which any funds sent to this contract will be forwarded
    address private parentContract;
    address private coldWallet;
    IWallet private parentInstance;

    /**
    * Modifier that will execute internal code block only if the sender is the parent address
    */
    modifier onlyParent {
        require(msg.sender == parentContract, "sender is not parent");
        _;
    }

    /**
    * Create the contract, and sets the destination address to that of the creator
    */
    constructor(address _coldWallet) public {
        parentContract = msg.sender;
        coldWallet = _coldWallet;
        parentInstance = IWallet(parentContract);
    }

    /**
    * Default function; Gets called when Ether is deposited, and forwards it to the parent address
    */
    function() public payable {
        // Transfer eth to coldwallet.
        coldWallet.transfer(msg.value);  
        // Emit Despoit event to parent contract.
        parentInstance.deposit(msg.sender, this, msg.value);    
  
    }


    /**
    * Execute a token transfer of the full balance from the forwarder token to the parent address
    * @param tokenContractAddress the address of the erc20 token contract
    */
    function flushTokens(address tokenContractAddress) public onlyParent {
        IERC20 instance = IERC20(tokenContractAddress);
        address forwarderAddress = address(this);
        uint forwarderBalance = instance.balanceOf(forwarderAddress);
        require(forwarderBalance != 0, "Token Balance is Zero");

        if (!instance.transfer(parentContract, forwarderBalance)) {
            revert("transfer failed !!!");
        }
    }

    /**
    * It is possible that funds were sent to this address before the contract was deployed.
    * We can flush those funds to the parent address.
    */
    function flush() public onlyParent {
        // throws on failure
        parentContract.transfer(address(this).balance);
    }
}

/**
 *
 * Parent Wallet Contract
 * ======================
 *
 */

contract Parent is Ownable {

    address public coldWallet;
    mapping (address => bool) private children;

    // Events
    event Deposit(address sender, address receiver, uint256 amount);
    event NewAddress(address[] newAddress);

    /**
    * Contract constructor.
    */
    constructor (address _coldWalletAddress) public {
        require(_coldWalletAddress != address(0));
        coldWallet = _coldWalletAddress;
    }

    /**
    * callback function.
    */
    function() public payable {
        // require(msg.value > 0, "value is not correct");

        // if(children[msg.sender]) {
        //     coldWallet.transfer(msg.value);
        // }

    }

    function deposit(address sender, address receiver, uint256 amount) public {
        emit Deposit(sender, receiver, amount);
    }

    /**
    *
    * Change Cold Wallet Address
    *
    * @param _newAddress the address of the new cold wallet address
    */
    function changeColdWallet(address _newAddress) external onlyOwner {
        require(_newAddress != address(0));
        coldWallet = _newAddress;
    }

    /**
    * Execute a token flush from one of the child addresses. This transfer needs only a single signature and can be done by any signer
    *
    * @param _childAddress the address of the child address to flush the tokens from
    * @param _tokenContractAddress the address of the erc20 token contract
    */
    function flushChildTokens(address _childAddress, address _tokenContractAddress) public onlyOwner {
        Child child = Child(_childAddress);
        child.flushTokens(_tokenContractAddress);
    }

    /**
    * Kill this contract.
    */
    function kill() public onlyOwner {
        selfdestruct(owner);
    }

    /**
    * Create a new contract (and also address) that forwards funds to this contract
    * returns address of newly created forwarder address
    */
    function createChild(uint _count) public onlyOwner {
        address[] memory newAddress = new address[](_count);

        for(uint i = 0; i < _count; i++) {
            newAddress[i] = new Child(coldWallet);
            children[newAddress[i]] = true;
        }

        emit NewAddress(newAddress);
    }

}
