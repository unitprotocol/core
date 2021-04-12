pragma abicoder v2;
import "../interfaces/IKeydonixOracleUsd.sol";

interface IKeydonixOracleEth {

    // returns Q112-encoded value
    function assetToEth(address asset, uint amount, IKeydonixOracleUsd.ProofDataStruct calldata proofData) external view returns (uint);
}