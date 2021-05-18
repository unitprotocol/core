interface IForceTransferAssetStore {
    function shouldForceTransfer ( address ) external view returns ( bool );
    function add ( address asset ) external;
}
