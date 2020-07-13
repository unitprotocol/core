const Migrations = artifacts.require("Migrations");

module.exports = function(deployer, network) {
  deployer.deploy(Migrations);
};
