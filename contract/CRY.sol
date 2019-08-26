pragma solidity >= 0.5.0;
import "./Owned.sol";
import "./StandardToken.sol";
import "./SafeMath.sol";
import "github.com/provable-things/ethereum-api/provableAPI.sol";
contract CRY is Owned, StandardToken, usingProvable, SafeMath {
    
    uint public startDate;
    uint public bonusEnds;
    uint public endDate;    
    uint public ETHUSD;        //in cent
    uint public tokenPrice;    //in cent
    
    uint256 hashPower = 0;
    
    struct Pool {
        string algorithm;
        uint256 mul;
        string url;
        uint256 rawHash;
    }
    
    mapping (bytes32 => string) validIds;
    
    Pool[] public poolList;
    
    event LogNewProvableQuery(string description);

    constructor() StandardToken(1000, "Crytech Token", "CRY") payable public {
        //OAR = OracleAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        startDate = now;
        bonusEnds = now + 1 weeks;
        endDate = now + 7 weeks;
        tokenPrice = 450; // 4.5$
        updatePrice();
    }
    
    function getBalance() public view returns (uint256 balance) {
        return address(this).balance;
    }

    function mintToken(address target, uint256 mintedAmount) internal {
        balances[target] = safeAdd(balances[target], mintedAmount);
        totalSupply = safeAdd(totalSupply, mintedAmount);
    }
    
    function burnToken(address target, uint256 burnedAmount) internal {
        balances[target] = safeSub(balances[target], burnedAmount);
        totalSupply = safeSub(totalSupply, burnedAmount);
    }

    function setTokenPrice(uint price) onlyOwner public {
        tokenPrice = price;
    }

    // function buy() payable public returns (uint amount) {
    //     amount = msg.value / buyPrice;                  // calculates the amount
    //     require(balances[address(this)] >= amount);              // checks if it has enough to sell
    //     balances[msg.sender] += amount;                 // adds the amount to buyer's balance
    //     balances[address(this)] -= amount;                       // subtracts amount from seller's balance
    //     emit Transfer(address(this), msg.sender, amount);             // execute an event reflecting the change
    //     return amount;                                  // ends function and returns
    // }
    

    // function sell(uint256 _amount) public returns (uint revenue) {
    //     require(balances[msg.sender] >= _amount, "Insufficient token balance.");         // checks if the sender has enough to sell
    //     balances[address(this)] += _amount;                       // adds the amount to owner's balance
    //     balances[msg.sender] -= _amount;                  // subtracts the amount from seller's balance
    //     revenue = _amount * sellPrice;
    //     msg.sender.transfer(revenue);                     // sends ether to the seller: it's important to do this last to prevent recursion attacks
    //     emit Transfer(msg.sender, address(this), _amount);             // executes an event reflecting on the change
    //     return revenue;                                   // ends function and returns
    // }

    
    function __callback(bytes32 _myid, string memory _result) public
    {
        require(msg.sender == provable_cbAddress());
        require(bytes(validIds[_myid]).length > 0);
        if(keccak256(abi.encodePacked(validIds[_myid])) == keccak256(abi.encodePacked("updatePrice"))){
            ETHUSD = parseInt(_result, 2);
        }
        else {
            for(uint i=0;i<poolList.length;i++){
                if(keccak256(abi.encodePacked((poolList[i].algorithm))) == keccak256(abi.encodePacked((validIds[_myid]))) ){
                    poolList[i].rawHash = parseInt(_result);
                    break;
                }
            }
        }
        delete validIds[_myid];
        //updatePrice();
    }
    
    function updateHashRate(string memory algorithmName) payable public 
    {
    //   if (provable_getPrice("URL") > address(this).balance) {
    //       emit LogNewProvableQuery("Provable query was NOT sent, please add some ETH to cover for the query fee");
    //   } else {
    //       emit LogNewProvableQuery("Provable query was sent, standing by for the answer..");
    //       //provable_query("URL", "json(https://api.pro.coinbase.com/products/ETH-USD/ticker).price");
    //       provable_query("URL", "xml(https://www.fueleconomy.gov/ws/rest/fuelprices).fuelPrices.diesel");
    //   }
        // uint256 provablePrice = ;
        // uint256 currentBalance = address(this).balance;
        //require(provable_getPrice("URL") < address(this).balance, "Insufficient balance.");
        //provable_query("URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c.0");
      emit LogNewProvableQuery("Provable query was sent, standing by for the answer...");
      //bytes32 queryId = provable_query(10, "URL", "xml(https://www.fueleconomy.gov/ws/rest/fuelprices).fuelPrices.diesel",14000000);
      
      //bytes32 queryId = provable_query(10,"nested",poolUrl,14000000);
      //validIds[queryId].algorithm = algorithmName;
    }
    
    function updatePrice() payable public {
        bytes32 queryId = provable_query("URL", "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0");
        validIds[queryId] = "updatePrice";
    }
    
    function setPool(string memory algorithmName, uint256 mul, string memory url) onlyOwner public {
        require(bytes(algorithmName).length > 0 && bytes(url).length > 0 && mul > 0, "One of function parameters is empty!");
        bool poolExist = false;
        for(uint i=0;i<poolList.length;i++){
            if(keccak256(abi.encodePacked((poolList[i].algorithm))) == keccak256(abi.encodePacked((algorithmName))) ){
                poolList[i].mul = mul;
                poolList[i].url = url;
                poolExist = true;
            }
        }
         
        if(!poolExist){
            Pool memory newPool = Pool({ algorithm: algorithmName, mul:mul, url:url, rawHash:0 });
            poolList.push(newPool);
        }
    }
    
    function changeHashPower() internal {
        uint tempHashPower = 0;
        for(uint i=0;i<poolList.length;i++){
            tempHashPower = tempHashPower + (poolList[i].mul * poolList[i].rawHash);
        }
        hashPower = tempHashPower;
        if(hashPower > totalSupply){
            mintToken(owner, hashPower - totalSupply);
        }
        else if(hashPower < totalSupply){
            uint burnedAmount = totalSupply - hashPower;
            if (balances[owner] - burnedAmount < 0)
                burnToken(owner, balances[owner]);
            else
                burnToken(owner, burnedAmount);
        }
    }
    
    function () external payable {
        require(now >= startDate && now <= endDate);
        uint tokenPriceInWei = (tokenPrice/ETHUSD) * 10**18;
        uint tokens;
        if (now <= bonusEnds) {
            tokens = msg.value / tokenPriceInWei;
        } else {
            tokens = msg.value / tokenPriceInWei;
        }
        balances[msg.sender] = safeAdd(balances[msg.sender], tokens);
        totalSupply = safeAdd(totalSupply, tokens);
        emit Transfer(address(0), msg.sender, tokens);
        owner.transfer(msg.value);
    }
}