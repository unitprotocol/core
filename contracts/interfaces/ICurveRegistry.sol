interface ICurveRegistry {
    function get_pool_from_lp_token(address) external view returns (address);
    function get_n_coins(address) external view returns (uint[2] memory);
}