pragma solidity ^ 0.4.17;


library SafeMath {
    
    function mul(uint a, uint b) internal pure returns(uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function sub(uint a, uint b) internal pure  returns(uint) {
        assert(b <= a);
        return a - b;
    }

    function add(uint a, uint b) internal pure returns(uint) {
        uint c = a + b;
        assert(c >= a && c >= b);
        return c;
    }
}


contract ERC20 {

    uint public totalSupply;
 
    function balanceOf(address who) public view returns(uint);

    function allowance(address owner, address spender) public view returns(uint);

    function transfer(address to, uint value) public returns(bool ok);

    function transferFrom(address from, address to, uint value) public returns(bool ok);

    function approve(address spender, uint value) public returns(bool ok);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
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
        require(msg.sender == owner);
        _;
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) onlyOwner public {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

}


/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
    event Pause();
    event Unpause();

    bool public paused = false;

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
    modifier whenNotPaused() {
        require(!paused);
        _;
    }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
    modifier whenPaused() {
        require(paused);
        _;
    }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Pause();
    }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpause();
    }
}


// Crowdsale Smart Contract
// This smart contract collects ETH and in return sends tokens to contributors
contract Crowdsale is Pausable {

    using SafeMath for uint;

    struct Backer {
        uint weiReceived; // amount of ETH contributed
        uint tokensSent; // amount of tokens  sent  
        bool refunded; // true if user has been refunded       
    }

    Token public token; // Token contract reference   
    address public multisig; // Multisig contract that will receive the ETH    
    address public team; // Address at which the team tokens will be sent        
    uint public ethReceivedPresale; // Number of ETH received in presale
    uint public ethReceivedMain; // Number of ETH received in public sale
    uint public tokensSentPresale; // Tokens sent during presale
    uint public tokensSentMain; // Tokens sent during public ICO   
    uint public totalTokensSent; // Total number of tokens sent to contributors
    uint public startBlock; // Crowdsale start block
    uint public endBlock; // Crowdsale end block
    uint public maxCap; // Maximum number of tokens to sell
    uint public minCap; // Minimum number of ETH to raise
    uint public minInvestETH; // Minimum amount to invest   
    bool public crowdsaleClosed; // Is crowdsale still in progress
    Step public currentStep;  // To allow for controlled steps of the campaign 
    uint public refundCount;  // Number of refunds
    uint public totalRefunded; // Total amount of Eth refunded    
    uint public tokenPriceWei;  // Price of token in wei

    mapping(address => Backer) public backers; // contributors list
    address[] public backersIndex; // to be able to iterate through backers for verification.  

    // @notice to verify if action is not performed out of the campaign range
    modifier respectTimeFrame() {
        require(block.number >= startBlock && block.number <= endBlock);
        _;
    }

    // @notice to set and determine steps of crowdsale
    enum Step {      
        FundingPreSale,     // presale mode
        FundingPublicSale,  // public mode
        Refunding  // in case campaign failed during this step contributors will be able to receive refunds
    }

    // Events
    event ReceivedETH(address backer, uint amount, uint tokenAmount);
    event RefundETH(address backer, uint amount);


    // Crowdsale  {constructor}
    // @notice fired when contract is crated. Initializes all constant and initial values.
    constructor() public {               
        multisig = 0x6C88e6C76C1Eb3b130612D5686BE9c0A0C78925B; //TODO: Replace address with correct one
        team = 0x6C88e6C76C1Eb3b130612D5686BE9c0A0C78925B; //TODO: Replace address with correct one                                                                
        maxCap = 160000000e18;   // TODO: adjust maxCap by tokens sold in the private sale
        minCap = 16667 ether;
        tokenPriceWei = 1 ether/1000;  
        minInvestETH = 5 ether;     
        currentStep = Step.FundingPreSale;
    }

    // {fallback function}
    // @notice It will call internal function which handles allocation of Ether and calculates tokens.
    // contributor will be instructed to provide 250,000 gas
    function () external payable {           
        contribute(msg.sender);
    }

    // @notice Specify address of token contract
    // @param _tokenAddress {address} address of token contract
    function updateTokenAddress(Token _tokenAddress) external onlyOwner() {
        token = _tokenAddress;
    }

    // @notice It will be called by owner to start the sale    
    function start(uint _block) external onlyOwner() {   
        require(_block <= 371520);  // 4.3×60×24×60 days = 371520 assuming 4.3 blocks in minute       
        startBlock = block.number;
        endBlock = startBlock.add(_block); 
    }

      // @notice Due to changing average of block time
    // this function will allow on adjusting duration of campaign closer to the end 
    function adjustDuration(uint _block) external onlyOwner() {
        // 4.3*60*24*80 days = 495360 allow for 80 days of campaign assuming block takes 30 sec.
        require(_block < 495360);  
        require(_block > block.number.sub(startBlock)); // ensure that endBlock is not set in the past
        endBlock = startBlock.add(_block); 
    }

    // @notice set the step of the campaign from presale to public sale
    // contract is deployed in presale mode
    // WARNING: there is no way to go back
    function advanceStep() external onlyOwner() {

        currentStep = Step.FundingPublicSale;                                             
        minInvestETH = 1 ether/10;                                
    }

    // @notice in case refunds are needed, money can be returned to the contract
    // and contract switched to mode refunding
    function prepareRefund() external payable onlyOwner() {
        
        require(msg.value == ethReceivedPresale.add(ethReceivedMain)); // make sure that proper amount of ether is sent
        currentStep = Step.Refunding;
    }

    // @notice This function will finalize the sale.
    // It will only execute if predetermined sale time passed or all tokens are sold.
    // it will fail if minimum cap is not reached
    function finalize() external onlyOwner() {

        require(!crowdsaleClosed);        
        // purchasing precise number of tokens might be impractical, 
        // thus subtract 1000 tokens so finalization is possible
        // near the end 
        require(block.number >= endBlock || totalTokensSent >= maxCap - 1000); 
        
        uint totalEtherReceived = ethReceivedPresale + ethReceivedMain;
        require(totalEtherReceived >= minCap);  // ensure that minimum was reached
        crowdsaleClosed = true;                
        if (!token.transfer(team, token.balanceOf(this))) // transfer all remaining tokens to team address
            revert();
        token.unlock();               
    }

    // @notice Fail-safe drain
    function drain() external onlyOwner() {
        multisig.transfer(this.balance);               
    }

    // @notice Fail-safe token transfer
    function tokenDrain() external onlyOwner() {
        if (block.number > endBlock) {
            if (!token.transfer(team, token.balanceOf(this))) 
                revert();
        }
    }

    // @notice it will allow contributors to get refund in case campaign failed
    // @return {bool} true if successful
    function refund() external whenNotPaused returns (bool) {

        require(currentStep == Step.Refunding); 
        
        uint totalEtherReceived = ethReceivedPresale + ethReceivedMain;

        require(totalEtherReceived < minCap);  // ensure that campaign failed
        
        Backer storage backer = backers[msg.sender];

        require(backer.weiReceived > 0);  // ensure that user has sent contribution
        require(!backer.refunded);        // ensure that user hasn't been refunded yet

        backer.refunded = true;  // save refund status to true
        refundCount++;
        totalRefunded += backer.weiReceived;

        if (!token.burn(msg.sender, backer.tokensSent)) // burn tokens
            revert();        
        msg.sender.transfer(backer.weiReceived);  // send back the contribution 
        emit RefundETH(msg.sender, backer.weiReceived);
        return true;
    }

    // @notice return number of contributors
    // @return  {uint} number of contributors   
    function numberOfBackers() public view returns(uint) {
        return backersIndex.length;
    }
  
    // @notice It will be called by fallback function whenever ether is sent to it
    // @param  _backer {address} address of contributor
    // @return res {bool} true if transaction was successful
    function contribute(address _backer) internal whenNotPaused respectTimeFrame {

        uint tokensToSend = determindPurchase();
            
        Backer storage backer = backers[_backer];

        if (backer.weiReceived == 0)
            backersIndex.push(_backer);

        backer.tokensSent = backer.tokensSent + tokensToSend; // save contributor's total tokens sent
        backer.weiReceived = backer.weiReceived.add(msg.value);  // save contributor's total ether contributed

        if (Step.FundingPublicSale == currentStep) { // Update the total Ether received and tokens sent during public sale
            ethReceivedMain = ethReceivedMain.add(msg.value);
            tokensSentMain = tokensSentMain + tokensToSend;
        }else {                                                 // Update the total Ether recived and tokens sent during presale
            ethReceivedPresale = ethReceivedPresale.add(msg.value); 
            tokensSentPresale = tokensSentPresale + tokensToSend;
        }                                                     
        totalTokensSent = totalTokensSent + tokensToSend;     // update the total amount of tokens sent  
        if (!token.transfer(_backer, tokensToSend)) // Transfer tokens
            revert();      
        multisig.transfer(msg.value);   // transfer funds to multisignature wallet             
        emit ReceivedETH(_backer, msg.value, tokensToSend); // Register event       
    }

    // @notice It is called by determindPurchase() to determine amount of tokens for given contribution
    // @param _tokenAmount {uint} basic amount of tokens
    // @return tokensToPurchase {uint} amount of tokens to purchase
    function calculateNoOfTokensToSend(uint _tokenAmount) internal view returns(uint) {                                          

        if (tokensSentMain <= 26000000e18)        // First 26,000,000 30% discount
            return _tokenAmount + ((_tokenAmount * 30) / 100);                 
        else if (tokensSentMain <= 50000000e18)   // next 24,000,000 20% discount 
            return _tokenAmount + ((_tokenAmount * 20) / 100); 
        else if (tokensSentMain <= 72000000e18)   // next 22,000,000 10% discount
            return _tokenAmount + ((_tokenAmount * 10) / 100);                     
        else                                            // remaining 46,000,000 0%
            return _tokenAmount;
    }

    // @notice determine if purchase is valid and return proper number of tokens
    // @return tokensToSend {uint} proper number of tokens based on the timline
    function determindPurchase() internal view returns (uint) {
       
        require(msg.value >= minInvestETH);   // ensure that min contributions amount is met

        // calculate amount of tokens to send  (add 18 0s first)   
        uint tokensToSend = msg.value.mul(1e18) / tokenPriceWei;  // basic nmumber of tokens to send
          
        if (Step.FundingPublicSale == currentStep)   // calculate stepped price of token in public sale
            tokensToSend = calculateNoOfTokensToSend(tokensToSend); 
        else                                         // calculate number of tokens for presale with 50% bonus
            tokensToSend = tokensToSend.add((tokensToSend * 50) / 100);
          
        require(totalTokensSent.add(tokensToSend) < maxCap); // Ensure that max cap hasn't been reached  

        return tokensToSend;
    }
}

// @notice The token contract

contract Token is ERC20, Ownable {

    using SafeMath for uint;
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals; // How many decimals to show.
    string public version = "v0.1";       
    uint public totalSupply;
    bool public locked;
    address public crowdSaleAddress;
    


    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowed;

    // @notice tokens are locked during the ICO. Allow transfer of tokens after ICO. 
    modifier onlyUnlocked() {
        if (msg.sender != crowdSaleAddress && locked) 
            revert();
        _;
    }

    // @Notice allow burning of tokens only by authorized users 
    modifier onlyAuthorized() {
        if (msg.sender != owner && msg.sender != crowdSaleAddress) 
            revert();
        _;
    }

    // @notice The Token constructor
    // @param _crowdSaleAddress {address} address of crowdsale contract
    // @param _tokensSoldPrivateSale {uint} tokens sold during private sale
    constructor (address _crowdSaleAddress, uint _tokensSoldPrivateSale) public {
        
        locked = true;  // Lock the transfCrowdsaleer function during the crowdsale
        totalSupply = 250000000e18; 
        name = "Auditchain"; // Set the name for display purposes
        symbol = "AUDT"; // Set the symbol for display purposes
        decimals = 18; // Amount of decimals for display purposes
        crowdSaleAddress = _crowdSaleAddress;  
        balances[crowdSaleAddress] = 160000000e18 - _tokensSoldPrivateSale;  // maxCap is 160000000e18       
        balances[owner] = totalSupply - balances[crowdSaleAddress];
    }

    // @notice unlock tokens for trading
    function unlock() public onlyAuthorized {
        locked = false;
    }

    // @notice lock tokens in case of problems
    function lock() public onlyAuthorized {
        locked = true;
    }

    // @notice burn tokens in case campaign failed
    // @param _member {address} of member
    // @param _value {uint} amount of tokens to burn
    // @return  {bool} true if successful
    function burn( address _member, uint256 _value) public onlyAuthorized returns(bool) {
        balances[_member] = balances[_member].sub(_value);
        totalSupply = totalSupply.sub(_value);
        emit Transfer(_member, 0x0, _value);
        return true;
    }

    // @notice transfer tokens to given address 
    // @param _to {address} address or recipient
    // @param _value {uint} amount to transfer
    // @return  {bool} true if successful  
    function transfer(address _to, uint _value) public onlyUnlocked returns(bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // @notice transfer tokens from given address to another address
    // @param _from {address} from whom tokens are transferred 
    // @param _to {address} to whom tokens are transferred
    // @parm _value {uint} amount of tokens to transfer
    // @return  {bool} true if successful   
    function transferFrom(address _from, address _to, uint256 _value) public onlyUnlocked returns(bool success) {
        require(balances[_from] >= _value); // Check if the sender has enough                            
        require(_value <= allowed[_from][msg.sender]); // Check if allowed is greater or equal        
        balances[_from] = balances[_from].sub(_value); // Subtract from the sender
        balances[_to] = balances[_to].add(_value); // Add the same to the recipient
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    // @notice to query balance of account
    // @return _owner {address} address of user to query balance 
    function balanceOf(address _owner) public view returns(uint balance) {
        return balances[_owner];
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    *
    * Beware that changing an allowance with this method brings the risk that someone may use both the old
    * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
    * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
    * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
    */
    function approve(address _spender, uint _value) public returns(bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // @notice to query of allowanc of one user to the other
    // @param _owner {address} of the owner of the account
    // @param _spender {address} of the spender of the account
    // @return remaining {uint} amount of remaining allowance
    function allowance(address _owner, address _spender) public view returns(uint remaining) {
        return allowed[_owner][_spender];
    }

    /**
    * approve should be called when allowed[_spender] == 0. To increment
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    */
    function increaseApproval (address _spender, uint _addedValue) public returns (bool success) {
        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) public returns (bool success) {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

}