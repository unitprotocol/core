// SPDX-License-Identifier: UNLICENSED
// Origin Shiba contracts slightly changed for run in tests
// see https://etherscan.io/address/0xa404f66b9278c4ab8428225014266b4b239bcdc7#code

pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../../interfaces/wrapped-assets/IBoneLocker.sol";

/**
 * @title BoneLocker_Mock
 * @dev Implementation of the IBoneLocker interface to create a mock BoneToken locker contract.
 */
contract BoneLocker_Mock is IBoneLocker, Ownable {
    using SafeMath for uint256;
    IERC20 boneToken;
    address emergencyAddress;
    bool emergencyFlag = false;

    struct LockInfo {
        uint256 _amount;
        uint256 _timestamp;
        bool _isDev;
    }

    uint256 public override lockingPeriod;
    uint256 public devLockingPeriod;

    mapping (address => LockInfo[]) public override lockInfoByUser;
    mapping (address => uint256) public latestCounterByUser;
    mapping (address => uint256) public unclaimedTokensByUser;

    event LockingPeriod(address indexed user, uint newLockingPeriod, uint newDevLockingPeriod);

    /**
     * @dev Sets the initial values for {_boneToken}, {emergencyAddress}, {lockingPeriod}, and {devLockingPeriod}.
     * @param _boneToken The address of the BoneToken.
     * @param _emergencyAddress The address that can trigger the emergency mode.
     * @param _lockingPeriodInDays The number of days for the normal locking period.
     * @param _devLockingPeriodInDays The number of days for the developer locking period.
     */
    constructor(address _boneToken, address _emergencyAddress, uint256 _lockingPeriodInDays, uint256 _devLockingPeriodInDays) {
        require(address(_boneToken) != address(0), "_bone token is a zero address");
        require(address(_emergencyAddress) != address(0), "_emergencyAddress is a zero address");
        boneToken = IERC20(_boneToken);
        emergencyAddress = _emergencyAddress;
        lockingPeriod = _lockingPeriodInDays * 1 days;
        devLockingPeriod = _devLockingPeriodInDays * 1 days;
    }

    /**
     * @dev Locks a given amount of BoneToken for a specified user.
     * @param _holder The address of the user whose tokens are to be locked.
     * @param _amount The amount of tokens to be locked.
     * @param _isDev A boolean to indicate if the locking is for a developer.
     */
    function lock(address _holder, uint256 _amount, bool _isDev) external override onlyOwner {
        require(_holder != address(0), "Invalid user address");
        require(_amount > 0, "Invalid amount entered");

        lockInfoByUser[_holder].push(LockInfo(_amount, block.timestamp, _isDev));
        unclaimedTokensByUser[_holder] = unclaimedTokensByUser[_holder].add(_amount);
    }

    /**
     * @dev Claims all the tokens locked for a user after the locking period.
     * @param r The upper boundary of the range of LockInfo entries to claim for the user.
     * @param user The address of the user for whom to claim tokens.
     */
    function claimAllForUser(uint256 r, address user) public override {
        require(!emergencyFlag, "Emergency mode, cannot access this function");
        require(r>latestCounterByUser[user], "Increase right header, already claimed till this");
        require(r<=lockInfoByUser[user].length, "Decrease right header, it exceeds total length");
        
        LockInfo[] memory lockInfoArrayForUser = lockInfoByUser[user];
        uint256 totalTransferableAmount = 0;
        uint i;
        for (i=latestCounterByUser[user]; i<r; i++){
            uint256 lockingPeriodHere = lockingPeriod;
            if (lockInfoArrayForUser[i]._isDev) {
                lockingPeriodHere = devLockingPeriod;
            }
            if (block.timestamp >= (lockInfoArrayForUser[i]._timestamp.add(lockingPeriodHere))) {
                totalTransferableAmount = totalTransferableAmount.add(lockInfoArrayForUser[i]._amount);
                unclaimedTokensByUser[user] = unclaimedTokensByUser[user].sub(lockInfoArrayForUser[i]._amount);
                latestCounterByUser[user] = i.add(1);
            } else {
                break;
            }
        }
        boneToken.transfer(user, totalTransferableAmount);
    }

    /**
     * @dev Claims all the tokens locked by the sender after the locking period.
     * @param r The upper boundary of the range of LockInfo entries to claim for the sender.
     */
    function claimAll(uint256 r) external override {
        claimAllForUser(r, msg.sender);
    }

    /**
     * @dev Returns the amount of tokens that are claimable for a user.
     * @param _user The address of the user to check claimable amount for.
     * @return totalTransferableAmount The total amount of tokens that can be claimed by the user.
     */
    function getClaimableAmount(address _user) external override view returns (uint256 totalTransferableAmount) {
        LockInfo[] memory lockInfoArrayForUser = lockInfoByUser[_user];
        uint256 totalTransferableAmount = 0;
        uint i;
        for (i=latestCounterByUser[_user]; i<lockInfoArrayForUser.length; i++){
            uint256 lockingPeriodHere = lockingPeriod;
            if (lockInfoArrayForUser[i]._isDev) {
                lockingPeriodHere = devLockingPeriod;
            }
            if (block.timestamp >= (lockInfoArrayForUser[i]._timestamp.add(lockingPeriodHere))) {
                totalTransferableAmount = totalTransferableAmount.add(lockInfoArrayForUser[i]._amount);
            } else {
                break;
            }
        }
    }

    /**
     * @dev Returns the left and right counters for a user's lockInfo array.
     * @param _user The address of the user to check the counters for.
     * @return The left and right counters for the user's lockInfo array.
     */
    function getLeftRightCounters(address _user) external override view returns (uint256, uint256) {
        return (latestCounterByUser[_user], lockInfoByUser[_user].length);
    }

    /**
     * @dev Sets the emergency flag to enable or disable emergency functions.
     * @param _emergencyFlag The new value of the emergency flag.
     */
    function setEmergencyFlag(bool _emergencyFlag) external {
        require(msg.sender == emergencyAddress, "This function can only be called by emergencyAddress");
        emergencyFlag = _emergencyFlag;
    }

    /**
     * @dev Allows the owner to withdraw all tokens to another address in case of emergency.
     * @param _to The address to which the tokens will be transferred.
     */
    function emergencyWithdrawOwner(address _to) external override onlyOwner {
        uint256 amount = boneToken.balanceOf(address(this));
        require(boneToken.transfer(_to, amount), 'MerkleDistributor: Transfer failed.');
    }

    /**
     * @dev Updates the emergency address.
     * @param _newAddr The new emergency address.
     */
    function setEmergencyAddr(address _newAddr) external {
        require(msg.sender == emergencyAddress, "This function can only be called by emergencyAddress");
        require(_newAddr != address(0), "_newAddr is a zero address");
        emergencyAddress = _newAddr;
    }

    /**
     * @dev Updates the locking periods for normal and developer locks.
     * @param _newLockingPeriod The new normal locking period in seconds.
     * @param _newDevLockingPeriod The new developer locking period in seconds.
     */
    function setLockingPeriod(uint256 _newLockingPeriod, uint256 _newDevLockingPeriod) external override onlyOwner {
        lockingPeriod = _newLockingPeriod;
        devLockingPeriod = _newDevLockingPeriod;
        emit LockingPeriod(msg.sender, _newLockingPeriod, _newDevLockingPeriod);
    }
}