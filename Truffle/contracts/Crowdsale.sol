pragma solidity ^ 0.4.24;

import "./Pausable.sol";
import "./SafeMath.sol";
import "./Token.sol";


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

    event LogContractDeployed(address _contract);


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
        emit LogContractDeployed(this);
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

        require(_tokenAddress != address(0), "Token address can't be nothing");
        token = _tokenAddress;
    }

    // @notice It will be called by owner to start the sale    
    // @param _block {uint} count of blocks defining length of the campin based on the length of block  
    function start(uint _block) external onlyOwner() {   
        //TODO: enter proper block number
        // 4.3×60×24×60 days = 371520 assuming 4.3 blocks in a minute 
        require(_block <= 371520, "Length of campaign can't be longer than 371520 blocks");       
        startBlock = block.number;
        endBlock = startBlock.add(_block); 
    }

      // @notice Due to changing average of block time
    // this function will allow on adjusting duration of campaign closer to the end 
    function adjustDuration(uint _block) external onlyOwner() {
        // 4.3*60*24*80 days = 495360 allow for 80 days of campaign assuming block takes 30 sec.
        require(startBlock > 0, "The campaign hasn't been started yet");
        require(_block < 495360, "The campaign can be only extended to max 495360 blocks");  
        // ensure that endBlock is not set in the past
        require(startBlock.add(_block) > block.number, "Blocks can't be set in the past"); 
        endBlock = startBlock.add(_block); 
    }

    // @notice set the step of the campaign from presale to public sale
    // contract is deployed in presale mode
    // WARNING: there is no way to go back
    function advanceStep() external onlyOwner() {

        require(startBlock != 0, "Campaign hasn't been started yet");

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
        multisig.transfer(address(this).balance);               
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
            revert("There was a problem transferring tokens");      
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
       
        require(msg.value >= minInvestETH, "You have not met minimum contribution amount");   // ensure that min contributions amount is met

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
