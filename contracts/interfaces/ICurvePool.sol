interface ICurvePool {
    function get_virtual_price() external view returns (uint);
    function coins(uint) external view returns (address);
}