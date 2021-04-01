interface IOracleEth {
    function assetToEth(address asset, uint amount) external view returns (uint);
    function ethToUsd(uint amount) external view returns (uint);
}