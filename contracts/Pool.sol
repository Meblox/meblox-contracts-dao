// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import './IUniswapV2Pair.sol';

contract Pool is Ownable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using SafeMath for uint128;
    using SafeMath for uint112;
    using SafeMath for uint64;

    address mTokenAddress;

    /// operateType: 1:deposit, 2:withdraw
    struct DepositRecord {
        int operateType;
        address userAddress;
        uint256 startBlockNumber;
        uint256 endBlockNumber;
        uint256 userDepositAmount;
        uint256 nowlpPrice;
        uint256 userDepositPrice;
    }

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    struct UserInfo {
        uint256 balance;
    }

    /// @notice Address of the LP token for each MCV2 pool.
    /// `lockBlockCount` 3 sec per block.
    /// `minDepositLimit` The minimum amount to deposit.
    /// `minDepositPercent` The minimum percent of lp price.
    /// `totalBalance` The total balance of the pool.
    struct PoolInfo {
        IERC20 lpToken;
        uint256 lockBlockCount;
        uint256 minFirstDepositLimit;
        uint256 minDepositLimit;
        uint256 totalBalance;
    }

    /// @notice Address of the LP token for each MCV2 pool.
    IERC20[] public lpToken;

    /// @notice Info of each MCV2 pool.
    PoolInfo[] public poolInfoList;

    mapping (address => UserInfo) public userInfoList;

    /// @notice Info of each user that stakes LP tokens.
    mapping (address => mapping (uint256 => DepositRecord[])) public userDepositRecordList;

    event LogAddPool(uint256 indexed poolId, IERC20 _lpToken, uint256 lockBlockCount, uint256 depositLimit, uint256 firstDepositLimit);
    event LogSetPool(uint256 indexed poolId, uint256 minDepositLimit, uint256 _minFirstDepositLimit);
    event LogSetMTokenAddress(address);
    event LogDepositLp(uint256 indexed poolId, address, uint256 depositLpAmount, uint256 lastBlock, uint256 lpPrice, uint256 depositPrice);
    event LogWithdrawLp(uint256 indexed poolId, address, uint256 lastBlock, uint256 depositPrice, uint256 depositLpAmount);

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _lockBlockCount The pledge time is inferred from the number of blocks.
    /// @param _depositLimit The minimum amount to deposit.
    function addPool(IERC20 _lpToken, uint256 _lockBlockCount, uint256 _depositLimit, uint256 _firstDepositLimit) public onlyOwner {
        lpToken.push(_lpToken);
        poolInfoList.push(
            PoolInfo({
                lpToken: _lpToken,
                lockBlockCount: _lockBlockCount,
                minDepositLimit: _depositLimit,
                minFirstDepositLimit: _firstDepositLimit,
                totalBalance: 0
            })
        );
        emit LogAddPool(lpToken.length.sub(1), _lpToken, _lockBlockCount, _depositLimit, _firstDepositLimit);
    }

    /// @notice Update the given pool . Can only be called by the owner.
    /// @param _poolId The index of the pool. See `poolInfo`.
    /// @param _minDepositLimit The minimum amount to deposit.
    function setPool(uint256 _poolId, uint256 _minDepositLimit, uint256 _minFirstDepositLimit) public onlyOwner {
        PoolInfo storage pool = poolInfoList[_poolId];
        pool.minDepositLimit = _minDepositLimit;
        pool.minFirstDepositLimit = _minFirstDepositLimit;
        emit LogSetPool(_poolId, _minDepositLimit, _minFirstDepositLimit);
    }

    function setMTokenAddress(address _mTokenAddress) public onlyOwner {
        mTokenAddress = _mTokenAddress;
        emit LogSetMTokenAddress(_mTokenAddress);
    }

    function getMTokenAddress() public view returns (address) {
        return mTokenAddress;
    }

    /// @notice Deposit LP tokens to MCV2 for Meblox allocation.
    function deposit(uint256 _poolId, uint256 _depositLpAmount) public {
        require(_depositLpAmount > 0, "Pool: DepositAmount must great than 0");
        PoolInfo storage pool = poolInfoList[_poolId];
        uint256 lpPrice = getLpPrice(_poolId);

        UserInfo storage user = userInfoList[msg.sender];

        uint256 userDepositPrice = _depositLpAmount.mul(lpPrice).div(10**18);

        if (user.balance <= pool.minFirstDepositLimit) {
            /// first
            require(userDepositPrice >= pool.minFirstDepositLimit, "[First]Pool: Insufficient amount of deposit");
        } else {
            /// not first 
            require(userDepositPrice >= pool.minDepositLimit, "[Not First]Pool: Insufficient amount of deposit");
        }

        pool.lpToken.safeTransferFrom(msg.sender, address(this), _depositLpAmount);

        uint256 totalBalance = pool.totalBalance.add(_depositLpAmount);
        uint256 lastBlock = block.number;

        userDepositRecordList[msg.sender][_poolId].push(
            DepositRecord({
                operateType: 1,
                userAddress: msg.sender,
                startBlockNumber: lastBlock,
                endBlockNumber: lastBlock.add(pool.lockBlockCount),
                userDepositAmount: _depositLpAmount,
                nowlpPrice: lpPrice,
                userDepositPrice: userDepositPrice
            })
        );

        user.balance = user.balance.add(userDepositPrice);
        pool.totalBalance = totalBalance;

        emit LogDepositLp(_poolId, msg.sender, _depositLpAmount, lastBlock, lpPrice, userDepositPrice);
    }

    function withdraw(uint256 _poolId, uint256 _depositRecordId) public {

        DepositRecord storage userDepositRecord = userDepositRecordList[msg.sender][_poolId][_depositRecordId];

        require(userDepositRecord.operateType == 1, "Already withdrawal");
        require(userDepositRecord.endBlockNumber <= block.number, "Time has not arrived");

        PoolInfo storage pool = poolInfoList[_poolId];
        UserInfo storage user = userInfoList[msg.sender];
        pool.lpToken.safeTransfer(msg.sender, userDepositRecord.userDepositAmount);
        userDepositRecord.operateType = 2;

        user.balance = user.balance.sub(userDepositRecord.userDepositPrice);
        pool.totalBalance = pool.totalBalance.sub(userDepositRecord.userDepositAmount);

        emit LogWithdrawLp(_poolId, msg.sender, block.number, userDepositRecord.userDepositPrice, userDepositRecord.userDepositAmount);
    }

    function getDepositRecordList(uint256 _poolId) public view returns (DepositRecord[] memory) {
        return userDepositRecordList[msg.sender][_poolId];
    }

    function getLpTotalSupply(uint256 _poolId) public view returns (uint256 _totalSupply) {
        PoolInfo memory pool = poolInfoList[_poolId];
        IERC20 tract = IERC20(pool.lpToken);
        return tract.totalSupply();
    }

    function getUserBalance () public view returns (uint256) {
        return userInfoList[msg.sender].balance;
    }

    function getPools() public view returns (PoolInfo[] memory) {
        return poolInfoList;
    }

    function getLpPrice(uint256 _poolId) public view returns (uint256) {
        PoolInfo memory pool = poolInfoList[_poolId];
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(address(pool.lpToken)).getReserves();
        uint112 reserveMToken = reserve0;
        address token0 = IUniswapV2Pair(address(pool.lpToken)).token0();
        if (mTokenAddress == token0) {
            reserveMToken = reserve1;
        }
        uint256 totalSupply = getLpTotalSupply(_poolId);
        uint256 result = reserveMToken.mul(10**18).div(totalSupply).mul(2);
        return result;
    }

    function getDepositRecordListExternal(address _userAddress, uint256 _poolId) public view returns (DepositRecord[] memory) {
        return userDepositRecordList[_userAddress][_poolId];
    }

    function getDepositRecordItemExternal(address _userAddress, uint256 _poolId, uint256 _recordId) public view returns (DepositRecord memory) {
        return userDepositRecordList[_userAddress][_poolId][_recordId];
    }
}
