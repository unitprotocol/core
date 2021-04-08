interface IOracleEth {

    // returns Q112-encoded value
    // returned value 10**18 * 2**112 is 1 Ether
    function assetToEth(address asset, uint amount) external view returns (uint);

    // returns the value "as is"
    function ethToUsd(uint amount) external view returns (uint);

    // returns the value "as is"
    function usdToEth(uint amount) external view returns (uint);
}