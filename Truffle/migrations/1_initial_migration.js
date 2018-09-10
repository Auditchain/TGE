var Migrations = artifacts.require("./Migrations.sol");
const Token = artifacts.require('./Token.sol');
const crowdFounding = artifacts.require('./Crowdsale.sol')

module.exports = function(deployer) {
  deployer.deploy(Migrations);
  deployer.deploy(crowdFounding).then(function() {

   return deployer.deploy(Token, crowdFounding.address, 0);
  });
}
