interface IOracleForAsset {

    // returns Q112-encoded value
    function assetToUsd(address asset, uint amount) external view returns (uint);

    // returns Q112-encoded value
    function assetToEth(address asset, uint amount) external view returns (uint);
}