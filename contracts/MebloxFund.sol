// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface SwapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface SwapV2Router02 is SwapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract MebloxFund is Ownable {
    using SafeERC20 for IERC20;

    struct OperationRecords {
        address operateAddress;
        uint256 operateType;
        uint256 timestamp;
        uint256 operateMethods;
        uint256[] amount;
    }

    address public swapRouterAddress;
    address public swapResultAddress;

    address public lpTokenAddress;
    address public lpExactTokenAddress;

    uint256 public currentPage;
    
    address [] public operatorList;
    mapping (address => bool) public operatorPermissions;
    mapping (uint256 => OperationRecords[]) public operationRecordsList;

    event LogSetOperator(address operatorAddress, bool permissions);
    event LogOwnerTransfer(IERC20 tokenAddress, uint256 amount, address to);
    event LogOperatorSwap(uint256 amount, address swapAddress);
    event LogSwapRecord(uint _amount1, uint _amount2);
    event LogReceived(address, uint);
    event LogFallback(address, uint);

    function getOperationRecordsList(uint256 _currentPage) public view returns(OperationRecords[] memory) {
        return operationRecordsList[_currentPage];
    }

    function setSwapRouterAddress(address _swapRouterAddress) public onlyOwner {
        swapRouterAddress = _swapRouterAddress;
    }

    function setSwapResultAddress(address _swapResultAddress) public onlyOwner {
        swapResultAddress = _swapResultAddress;
    }

    function setLpTokenAddress(address _lpTokenAddress) public onlyOwner {
        lpTokenAddress = _lpTokenAddress;
    }

    function setLpExactTokenAddress(address _lpExactTokenAddress) public onlyOwner {
        lpExactTokenAddress = _lpExactTokenAddress;
    }

    function setOperator(address _operatorAddress, bool _permissions) public onlyOwner {
        operatorPermissions[_operatorAddress] = _permissions;
        if (_permissions) {
            operatorList.push(_operatorAddress);
        }
        emit LogSetOperator(_operatorAddress, _permissions);
    }

    function ownerTransfer(IERC20 _tokenAddress, uint256 _amount, address _to) public onlyOwner {
        _tokenAddress.safeTransfer(_to, _amount);
        emit LogOwnerTransfer(_tokenAddress, _amount, _to);
    }

    function tokensToExactTokens(uint256 _amountOut, uint256 _amountInMax, uint256 _deadline, uint256 _type) public payable {
        require(operatorPermissions[msg.sender], "You are not Operator");
        address[] memory path = getPath(_type);
        IERC20 exactTokens = IERC20(path[0]);
        exactTokens.approve(swapRouterAddress, _amountInMax);
        SwapV2Router02 uniswapRouter = SwapV2Router02(swapRouterAddress);
        uint256[] memory swapResult = uniswapRouter.swapTokensForExactTokens(_amountOut, _amountInMax, path, swapResultAddress, _deadline);
        operationRecordsList[currentPage].push(
            OperationRecords({
                operateAddress: msg.sender,
                operateType: _type,
                operateMethods: 1,
                timestamp: block.timestamp,
                amount: swapResult
            })
        );
        if (operationRecordsList[currentPage].length > 200) {
            currentPage++;
        }
    }

    function exactTokensToTokens(uint256 _amountIn, uint256 _amountOutMin, uint256 _deadline, uint256 _type) public payable {
        require(operatorPermissions[msg.sender], "You are not Operator");
        address[] memory path = getPath(_type);
        IERC20 exactTokens = IERC20(path[0]);
        exactTokens.approve(swapRouterAddress, _amountIn);
        SwapV2Router02 uniswapRouter = SwapV2Router02(swapRouterAddress);
        uint256[] memory swapResult = uniswapRouter.swapExactTokensForTokens(_amountIn, _amountOutMin, path, swapResultAddress, _deadline);
        operationRecordsList[currentPage].push(
            OperationRecords({
                operateAddress: msg.sender,
                operateType: _type,
                operateMethods: 2,
                timestamp: block.timestamp,
                amount: swapResult
            })
        );
        if (operationRecordsList[currentPage].length > 200) {
            currentPage++;
        }
    }

    function getPath(uint256 _type) public view returns(address[] memory)  {
        address[] memory path = new address[](2);
        if (_type == 1) {
            path[0] = lpExactTokenAddress;
            path[1] = lpTokenAddress;
        } else {
            path[0] = lpTokenAddress;
            path[1] = lpExactTokenAddress;
        }
        return path;
    }

    function withdraw(address payable _address, uint _withdrawAmount) public payable onlyOwner {
        _address.transfer(_withdrawAmount);
    }

    receive() external payable {
        emit LogReceived(msg.sender, msg.value);
    }

    fallback() external payable {
        emit LogFallback(msg.sender, msg.value);
    }
}

