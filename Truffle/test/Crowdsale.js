import {
    ensureException,
    Number,
    sums
} from './helpers/utils.js';

var myModule = require('./helpers/utils.js')
import should from 'should';

const Token = artifacts.require('./Token.sol');
const crowdFounding = artifacts.require('./Crowdsale.sol');

//let Web3 = require('web3');





contract('Crowdsale', accounts => {

    //accounts
    let issuer = accounts[0];
    let investor1 = accounts[1];
    let investor2 = accounts[2];
    let investor3 = accounts[3];
    let investor4 = accounts[4];
    let investor10 = accounts[9];


    //SecurityToken variables
    const name = 'Auditchain';
    const ticker = 'AUDT';
    const decimal = 18;
    const totalSupply = 250000000e18;
    const hardCap = 160000000e18;
    const privateSale = 100000e18;
    const ownerBalance = 9.01e+25; // totalSupply - hardCap + privateSale
    const blockLength = 371519;
    const newBlockLength = 495359;



    const version = '1.0';

    //

    let tokenInstance, ICOInstance;

    beforeEach(async () => {
        ICOInstance = await crowdFounding.new({
            from: issuer,
            gas: 5000000
        });

        tokenInstance = await Token.new(ICOInstance.address, privateSale, {
            from: issuer,
            gas: 5000000
        })
    });


    describe("Functions of Token", async () => {



        it("Deploy contract: Shouldn't deploy contract. Contract expects certain fees to be passed to it.", async () => {

            ICOInstance = await crowdFounding.new( {
                from: issuer,
                gas: 5000000
            });

            console.log("ICO contract created: " + ICOInstance.address);


            tokenInstance = await Token.new(ICOInstance.address, privateSale, {
                from: issuer,
                gas: 5000000
            })

            console.log("Token contract created: " + tokenInstance.address);
        });

        it("Constructor verify the parameters", async () => {
            //Match all the constructor parmaeters
            let symbol = await tokenInstance.symbol();
            assert.strictEqual(symbol.toString(), ticker);

            let securityOwner = await tokenInstance.owner();
            assert.equal(securityOwner, issuer);

            assert.equal(await tokenInstance.name(), name);

            const test = (await tokenInstance.balanceOf(issuer)).toNumber();

            assert.equal((await tokenInstance.decimals()).toNumber(), decimal);
            assert.equal((await tokenInstance.totalSupply()).toNumber(), totalSupply);
            assert.equal((await tokenInstance.balanceOf(issuer)).toNumber(), ownerBalance);


        });

    })

    describe("Functions of ICO", async () => {

        it("updateTokenAddress: Should update token address", async () => {

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            let tokenaddress = await ICOInstance.token.call();
            assert.strictEqual(tokenaddress, tokenInstance.address);

        });

        it("updateTokenAddress: Shouldn't update token address. Not a contract owner", async () => {

            try {
                await ICOInstance.updateTokenAddress(tokenInstance.address, {
                    from: investor1
                })
                ensureException();
            } catch (error) {
                ensureException(error);
            }
        });


        it("updateTokenAddress: Shouldn't update token address. Contract address not provided", async () => {

            try {
                await ICOInstance.updateTokenAddress("", {
                    from: issuer
                })
                ensureException();
            } catch (error) {
                ensureException(error);
            }
        });


        it("start: Should start ICO", async () => {

            const block = await web3.eth.blockNumber;
            await ICOInstance.start(blockLength, {
                from: issuer
            })

            let startBlock = await ICOInstance.startBlock.call();
            assert.equal(startBlock.toNumber(), block + 1);

        });

        it("start: Should fail starting ICO, block to high passed", async () => {

            try {
                await ICOInstance.start(blockLength + 10, {
                    from: issuer
                })
                ensureException()
            } catch (error) {
                ensureException(error);
            }

        });

        it("start: Should fail starting ICO, caller is not the contract owner", async () => {

            try {
                await ICOInstance.start(blockLength, {
                    from: investor1
                })
                ensureException(error)
            } catch (error) {
                ensureException(error);
            }

        });


        it("adjustDuration: Should increase ICO duration", async () => {


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.adjustDuration(newBlockLength, {
                from: issuer
            })

            let startBlock = await ICOInstance.startBlock.call();
            let endBlock = await ICOInstance.endBlock.call();
            assert.equal(startBlock.toNumber() + newBlockLength, endBlock.toNumber());

        });

        it("adjustDuration: Shouldn't increase ICO duration. Block too far in the future", async () => {

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            try {
                await ICOInstance.adjustDuration(newBlockLength + 10, {
                    from: issuer
                })
                ensureException(error)
            } catch (error) {
                ensureException(error);
            }

        });

        it("adjustDuration: Shouldn't increase ICO duration. Block too far in the past", async () => {


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            try {
                await ICOInstance.adjustDuration(1, {
                    from: issuer
                })
                ensureException()
            } catch (error) {
                ensureException(error);
            }

        });

        it("adjustDuration: Shouldn't adjust ICO duration. Campaign hasn't been started yet.", async () => {

            try {
                await ICOInstance.adjustDuration(blockLength, {
                    from: issuer
                })
                ensureException()
            } catch (error) {
                ensureException(error);
            }

        });

        it("adjustDuration: Shouldn't adjust ICO duration. The caller is not the contract owner.", async () => {

            await ICOInstance.start(blockLength, {
                from: issuer
            })


            try {
                await ICOInstance.adjustDuration(newBlockLength, {
                    from: investor1
                })
                ensureException()
            } catch (error) {
                ensureException(error);
            }

        });


        it("advanceStep: Should go to the main ICO campaign", async () => {

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            let currentStep = await ICOInstance.currentStep.call();
            assert.equal(currentStep.toNumber(), 1);
            let minInvestment = await ICOInstance.minInvestETH.call();
            assert.equal(minInvestment.toNumber(), 1e+17);



        });


        it("advanceStep: Shouldn't go to the main ICO campaign. Campaign hasn't been started yet.", async () => {

            try {
                await ICOInstance.advanceStep({
                    from: issuer
                })

                ensureException()
            } catch (error) {
                ensureException(error);
            }

        });


        it("advanceStep: Shouldn't go to the main ICO campaign. Caller is not the contract owner.", async () => {


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            try {
                await ICOInstance.advanceStep({
                    from: investor1
                })

                ensureException()
            } catch (error) {
                ensureException(error);
            }

        });


        it("contribute: Should allow to contribute to presale", async () => {

            let amountToSend = web3.toWei('10', 'Ether');

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })


            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });

            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            assert.equal(balanceSoFar.toNumber(), amountToSend);

        });


        it("contribute: Should allocate proper amount of tokens in presale with 50% bonus", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 50)/100) = 15000

            let amountToSend = web3.toWei('10', 'Ether');
            let tokenPrice = await ICOInstance.tokenPriceWei();

            let tokenAmount = (amountToSend / tokenPrice) * Math.pow(10, 18);
            tokenAmount += tokenAmount / 2; // tokenAmount + 50%

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })


            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });


            let investor1Balance = await tokenInstance.balanceOf(investor1);
            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();

            assert.equal(balanceSoFar.toNumber(), amountToSend);
            assert.equal(investor1Balance.toNumber(), tokenAmount);

        });


        it("contribute: Should allocate proper amount of tokens in public sale  with 30% bonus", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 30)/100) = 13000

            let amountToSend = web3.toWei('10', 'Ether');
            let tokenPrice = await ICOInstance.tokenPriceWei();

            let tokenAmount = (amountToSend / tokenPrice) * Math.pow(10, 18);
            tokenAmount += 30 * tokenAmount / 100; // tokenAmount + 30%            

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });


            let investor1Balance = await tokenInstance.balanceOf(investor1);
            let balanceSoFar = await ICOInstance.ethReceivedMain.call();

            assert.equal(balanceSoFar.toNumber(), amountToSend);
            assert.equal(investor1Balance.toNumber(), tokenAmount);

        });


        it("contribute: Should allocate proper amount of tokens in public sale  with 20% bonus", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 20)/100) = 12000

            let amountToSend = web3.toWei('10', 'Ether');

            let tokenPrice = await ICOInstance.tokenPriceWei();

            // to buy first bonus with 30%, 26000000 tokens needs to be sold - 30% at least. 

            let amountToBuyAllFirstBonus = (26000000 * tokenPrice) / Math.pow(10, 18);
            amountToBuyAllFirstBonus -= (amountToBuyAllFirstBonus * 10 / 100); // account for some bonuses

            //consoleconsole.log("amount of ether: " + amountToBuyAllFirstBonus);

            amountToBuyAllFirstBonus = web3.toWei(amountToBuyAllFirstBonus, 'Ether');



            let tokenAmount = (amountToSend / tokenPrice) * Math.pow(10, 18);
            tokenAmount += 20 * tokenAmount / 100; // tokenAmount + 30%            

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor2,
                    to: ICOInstance.address,
                    value: amountToBuyAllFirstBonus,
                    gas: 250000
                });

            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });


            let investor1Balance = await tokenInstance.balanceOf(investor1);
            //   let balanceSoFar = await ICOInstance.ethReceivedMain.call();

            // assert.equal(balanceSoFar.toNumber(), Number(amountToSend) + Number(amountToBuyAllFirstBonus));
            assert.equal(investor1Balance.toNumber(), tokenAmount);

        });



        it("contribute: Should allocate proper amount of tokens in public sale  with 10% bonus", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 20)/100) = 12000

            let amountToSend = web3.toWei('10', 'Ether');

            let tokenPrice = await ICOInstance.tokenPriceWei();

            // to buy first bonus with 30%, 26000000 tokens needs to be sold - 30% at least. 

            let amountToBuyAllFirstBonus = (50000000 * tokenPrice) / Math.pow(10, 18);
            amountToBuyAllFirstBonus -= (amountToBuyAllFirstBonus * 10 / 100); // account for some bonuses

            //console.log("amount of ether: " + amountToBuyAllFirstBonus);

            amountToBuyAllFirstBonus = web3.toWei(amountToBuyAllFirstBonus, 'Ether');



            let tokenAmount = (amountToSend / tokenPrice) * Math.pow(10, 18);
            tokenAmount += 10 * tokenAmount / 100; // tokenAmount + 30%            

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor2,
                    to: ICOInstance.address,
                    value: amountToBuyAllFirstBonus,
                    gas: 250000
                });

            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });


            let investor1Balance = await tokenInstance.balanceOf(investor1);
            //   let balanceSoFar = await ICOInstance.ethReceivedMain.call();

            // assert.equal(balanceSoFar.toNumber(), Number(amountToSend) + Number(amountToBuyAllFirstBonus));
            assert.equal(investor1Balance.toNumber(), tokenAmount);

        });

        it("contribute: Should allocate proper amount of tokens in public sale  with 0% bonus", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 20)/100) = 12000

            let amountToSend = web3.toWei('10', 'Ether');

            let tokenPrice = await ICOInstance.tokenPriceWei();

            // to buy first bonus with 30%, 26000000 tokens needs to be sold - 30% at least. 

            let amountToBuyAllFirstBonus = (72000000 * tokenPrice) / Math.pow(10, 18);
            amountToBuyAllFirstBonus -= (amountToBuyAllFirstBonus * 10 / 100); // account for some bonuses

            //console.log("amount of ether: " + amountToBuyAllFirstBonus);

            amountToBuyAllFirstBonus = web3.toWei(amountToBuyAllFirstBonus, 'Ether');



            let tokenAmount = (amountToSend / tokenPrice) * Math.pow(10, 18);


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor2,
                    to: ICOInstance.address,
                    value: amountToBuyAllFirstBonus,
                    gas: 250000
                });

            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });


            let investor1Balance = await tokenInstance.balanceOf(investor1);
            //   let balanceSoFar = await ICOInstance.ethReceivedMain.call();

            // assert.equal(balanceSoFar.toNumber(), Number(amountToSend) + Number(amountToBuyAllFirstBonus));
            assert.equal(investor1Balance.toNumber(), tokenAmount);

        });


        it("contribute: Should fail allocating tokens due to exceeding available cap", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 20)/100) = 12000

            let amountToSend = web3.toWei('10', 'Ether');

            let tokenPrice = await ICOInstance.tokenPriceWei();

            // to buy first bonus with 30%, 26000000 tokens needs to be sold - 30% at least. 

            let amountToBuyAll = (150000000 * tokenPrice) / Math.pow(10, 18);

            //console.log("amount of ether: " + amountToBuyAll);


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            try {
                await web3
                    .eth
                    .sendTransaction({
                        from: investor2,
                        to: ICOInstance.address,
                        value: amountToBuyAll,
                        gas: 250000
                    });
                ensureException();
            } catch (error) {
                ensureException(error);
            }



        });


        it("contribute: Should fail allocating tokens due to exceeding available time", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 20)/100) = 12000

            let amountToSend = web3.toWei('10', 'Ether');

            let tokenPrice = await ICOInstance.tokenPriceWei();


            await ICOInstance.start(1, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.advanceStep({
                from: issuer
            })

            try {
                await web3
                    .eth
                    .sendTransaction({
                        from: investor2,
                        to: ICOInstance.address,
                        value: amountToSend,
                        gas: 250000
                    });
                ensureException();
            } catch (error) {
                ensureException(error);
            }



        });


        it("contribute: Should fail allocating tokens due to emergency pause", async () => {


            // token price is 1 ether/1000
            // with 10 ehter contributor should get 10 * 1000 + ((10 * 1000 * 20)/100) = 12000

            let amountToSend = web3.toWei('10', 'Ether');

            let tokenPrice = await ICOInstance.tokenPriceWei();


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })


            await ICOInstance.pause({
                from: issuer
            })

            try {
                await web3
                    .eth
                    .sendTransaction({
                        from: investor2,
                        to: ICOInstance.address,
                        value: amountToSend,
                        gas: 250000
                    });
                ensureException();
            } catch (error) {
                ensureException(error);
            }



        });

        it("contribute: Should allow to contribute to presale after emergency pause and emergency unpause", async () => {

            let amountToSend = web3.toWei('10', 'Ether');

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await ICOInstance.pause({
                from: issuer
            })

            await ICOInstance.unpause({
                from: issuer
            })


            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });

            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            assert.equal(balanceSoFar.toNumber(), amountToSend);

        });


        it("contribute: Amount of contribution is properly transferred to dedicated account", async () => {

            let amountToSend = web3.toWei('10', 'Ether');
            let multisigAddress = await ICOInstance.multisig.call();
            let multisigEtherBalance = await web3.eth.getBalance(multisigAddress);           

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

           
            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });

            let multisigEtherBalanceAfter = await web3.eth.getBalance(multisigAddress);

            let investor1Balance = await tokenInstance.balanceOf(investor1);
            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();                                    

            // use of special function to add big numbers

            let addedBalance =  sums( multisigEtherBalance.toNumber().toFixedSpecial(0) ,  Number(amountToSend).toFixedSpecial(0));           

            assert.equal(multisigEtherBalanceAfter.toNumber() , Number(addedBalance));    
        });



        it("refund: Should allow to refund after failed campaign", async () => {

            let amountToSend = web3.toWei('10', 'Ether');

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });

            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            assert.equal(balanceSoFar.toNumber(), amountToSend);



            await ICOInstance.prepareRefund({
                from: issuer,
                value: amountToSend
            })

            let txReturn = await ICOInstance.refund({
                from: investor1
            })

            txReturn.logs[0].args.backer.should.equal(investor1);
            txReturn.logs[0].args.amount.toNumber().should.equal(Number(amountToSend));
        });



        it("refund: Should not allow to refund after failed campaign after second attempt", async () => {

            let amountToSend = web3.toWei('10', 'Ether');

            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor1,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });

            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            assert.equal(balanceSoFar.toNumber(), amountToSend);



            await ICOInstance.prepareRefund({
                from: issuer,
                value: amountToSend
            })

            let txReturn = await ICOInstance.refund({
                from: investor1
            })

            try {
                let txReturn = await ICOInstance.refund({
                    from: investor1
                })
                ensureException();
            } catch (error) {
                ensureException(error);

            }

        });


        it("refund: Should not allow to refund a member who never contributed", async () => {

            let amountToSend = web3.toWei('10', 'Ether');


            await ICOInstance.start(blockLength, {
                from: issuer
            })

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor2,
                    to: ICOInstance.address,
                    value: amountToSend,
                    gas: 250000
                });

            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            assert.equal(balanceSoFar.toNumber(), amountToSend);



            await ICOInstance.prepareRefund({
                from: issuer,
                value: amountToSend
            })



            try {
                let txReturn = await ICOInstance.refund({
                    from: investor1
                })
                ensureException();
            } catch (error) {
                ensureException(error);

            }

        });

        it("finalize: Should allow to finalize due to timeframe", async () => {


            let tokenPrice = await ICOInstance.tokenPriceWei();

            let minCap = await ICOInstance.minCap.call();
            minCap = minCap.toNumber();


            let tokenAmount = (minCap / tokenPrice) * Math.pow(10, 18);
            tokenAmount += tokenAmount * 50 / 100; // account for 50% of bonus in presale

            let multisigAddress = await ICOInstance.multisig.call();
            let multisigEtherBalance = await web3.eth.getBalance(multisigAddress);

            //console.log("multisig balance: " + multisigEtherBalance);



            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })



            await ICOInstance.start(2, {
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor2,
                    to: ICOInstance.address,
                    value: minCap,
                    gas: 250000
                });



            let contractBalanceAfter = await tokenInstance.balanceOf(ICOInstance.address);

            await ICOInstance.finalize({
                from: issuer
            })

            let teamAddress = await ICOInstance.team.call();
            let investor1Balance = await tokenInstance.balanceOf(investor2);
            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            let teamBalance = await tokenInstance.balanceOf(teamAddress);
            let multisigEtherBalanceAfter = await web3.eth.getBalance(multisigAddress);
            let tokenLockStatus = await tokenInstance.locked.call();


            //console.log("Multisig eth balance: " + multisigEtherBalance);

            assert.equal(balanceSoFar.toNumber(), minCap);
            assert.equal(investor1Balance.toNumber(), tokenAmount);
            assert.equal(teamBalance.toNumber(), contractBalanceAfter.toNumber());
            // assert.equal(multisigEtherBalanceAfter.toNumber() - multisigEtherBalance.toNumber(), minCap);
            assert.equal(tokenLockStatus, 0);
        });



        it("finalize: Should allow to finalize due to all tokens being sold", async () => {


            let tokenPrice = await ICOInstance.tokenPriceWei();
            let tokenForSaleAmtBalance = await tokenInstance.balanceOf(ICOInstance.address);
            let tokenForSaleAmt = tokenForSaleAmtBalance / 1.5; // take into acount 50% bonus in presale


            let amtToSend = tokenForSaleAmt * tokenPrice / Math.pow(10, 18);

            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })


            await ICOInstance.start(2, {
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor10,
                    to: ICOInstance.address,
                    value: amtToSend,
                    gas: 250000
                });


            let contractBalanceAfter = await tokenInstance.balanceOf(ICOInstance.address);
            await ICOInstance.finalize({
                from: issuer
            })


            let multisigAddress = await ICOInstance.multisig.call();
            let teamAddress = await ICOInstance.team.call();
            let investor1Balance = await tokenInstance.balanceOf(investor10);
            let balanceSoFar = await ICOInstance.ethReceivedPresale.call();
            let teamBalance = await tokenInstance.balanceOf(teamAddress);
            let multisigEtherBalanceAfter = await web3.eth.getBalance(multisigAddress);
            let tokenLockStatus = await tokenInstance.locked.call();

            assert.equal(balanceSoFar.toNumber(), amtToSend);
            assert.equal(investor1Balance.toNumber(), tokenForSaleAmtBalance);
            assert.equal(teamBalance.toNumber(), contractBalanceAfter.toNumber());
            assert.equal(tokenLockStatus, 0);

        });


        it("finalize: Should not allow to finalize due to campaign still in progress and tokens still available for sale", async () => {

            let amtToSend = web3.toWei('10', 'Ether');


            await ICOInstance.updateTokenAddress(tokenInstance.address, {
                from: issuer
            })


            await ICOInstance.start(1000, {
                from: issuer
            })

            await web3
                .eth
                .sendTransaction({
                    from: investor10,
                    to: ICOInstance.address,
                    value: amtToSend,
                    gas: 250000
                });

            try {
                let contractBalanceAfter = await tokenInstance.balanceOf(ICOInstance.address);
                await ICOInstance.finalize({
                    from: issuer
                })
                ensureException();
            } catch (error) {
                ensureException(error);

            }

        });





    });
})