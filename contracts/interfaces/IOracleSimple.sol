interface IOracleSimple {
    function assetToUsd(address asset, uint amount) external view returns (uint);
}