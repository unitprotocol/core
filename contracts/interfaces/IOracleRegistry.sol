pragma abicoder v2;


interface IOracleRegistry {

    struct Oracle {
        uint oracleType;
        address oracleAddress;
    }

    function WETH (  ) external view returns ( address );
    function getOracles (  ) external view returns ( Oracle[] memory foundOracles );
    function maxOracleType (  ) external view returns ( uint256 );
    function oracleByAsset ( address asset ) external view returns ( address );
    function oracleByType ( uint256 ) external view returns ( address );
    function oracleTypeByAsset ( address ) external view returns ( uint256 );
    function oracleTypeByOracle ( address ) external view returns ( uint256 );
    function setOracle ( uint256 oracleType, address oracle ) external;
    function setOracleTypeToAsset ( address asset, uint256 oracleType ) external;
    function setOracleTypeToAssets ( address[] memory assets, uint256 oracleType ) external;
    function vaultParameters (  ) external view returns ( address );
}
