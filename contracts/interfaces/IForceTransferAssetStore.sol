interface IForceTransferAssetStore {
    function shouldForceTransfer ( address ) external view returns ( bool );
    function vaultParameters (  ) external view returns ( address );
    function add ( address asset ) external;
}
