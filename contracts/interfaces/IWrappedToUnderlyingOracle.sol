interface IWrappedToUnderlyingOracle {
    function assetToUnderlying(address) external view returns (address);
}
