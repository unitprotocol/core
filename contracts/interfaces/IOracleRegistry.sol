interface IOracleRegistry {
    function oracleByAsset ( address ) external view returns ( address );
    function oracleByType ( uint256 ) external view returns ( address );
    function setOracle ( address asset, address oracle, uint256 oracleType ) external;
    function vaultParameters (  ) external view returns ( address );
}
