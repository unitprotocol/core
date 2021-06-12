interface IyvToken {
    function token() external view returns (address);
    function decimals() external view returns (uint256);
    function pricePerShare() external view returns (uint256);
    function emergencyShutdown() external view returns (bool);
}
