interface IcyToken {
    function underlying() external view returns (address);
    function implementation() external view returns (address);
    function decimals() external view returns (uint8);
    function exchangeRateStored() external view returns (uint);
}
