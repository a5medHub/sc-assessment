pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
// ------------------------------------------ //
// ----- END: DO NOT EDIT THIS SECTION ------ //  
// ------------------------------------------ //

  mapping (address => mapping (address => uint256)) private allowances;
  mapping (address => uint256) private holderIndex; // 1-based index in holders array
  address[] private holders;
  mapping (address => uint256) private dividends;
  function _syncHolder(address account) internal {
    bool hasBalance = balanceOf[account] > 0;
    uint256 idx = holderIndex[account];
    if (hasBalance && idx == 0) {
      holders.push(account);
      holderIndex[account] = holders.length;
    } else if (!hasBalance && idx != 0) {
      uint256 arrIndex = idx - 1;
      uint256 lastIndex = holders.length - 1;
      if (arrIndex != lastIndex) {
        address lastHolder = holders[lastIndex];
        holders[arrIndex] = lastHolder;
        holderIndex[lastHolder] = arrIndex + 1;
      }
      holders.pop();
      holderIndex[account] = 0;
    }
  }

  // IERC20

  function allowance(address owner, address spender) external view override returns (uint256) {
    return allowances[owner][spender];
  }

  function transfer(address to, uint256 value) external override returns (bool) {
    require(to != address(0), "invalid recipient");
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _syncHolder(msg.sender);
    _syncHolder(to);
    return true;
  }

  function approve(address spender, uint256 value) external override returns (bool) {
    allowances[msg.sender][spender] = value;
    return true;
  }

  function transferFrom(address from, address to, uint256 value) external override returns (bool) {
    require(to != address(0), "invalid recipient");
    allowances[from][msg.sender] = allowances[from][msg.sender].sub(value);
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);
    _syncHolder(from);
    _syncHolder(to);
    return true;
  }

  // IMintableToken

  function mint() external payable override {
    require(msg.value > 0, "no value");
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _syncHolder(msg.sender);
  }

  function burn(address payable dest) external override {
    require(dest != address(0), "invalid dest");
    uint256 amount = balanceOf[msg.sender];
    require(amount > 0, "nothing to burn");
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _syncHolder(msg.sender);
    dest.transfer(amount);
  }

  // IDividends

  function getNumTokenHolders() external view override returns (uint256) {
    return holders.length;
  }

  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > holders.length) {
      return address(0);
    }
    return holders[index - 1];
  }

  function recordDividend() external payable override {
    require(msg.value > 0, "empty dividend");
    require(totalSupply > 0, "no supply");
    uint256 len = holders.length;
    uint256 distributed = 0;
    for (uint256 i = 0; i < len; i++) {
      address h = holders[i];
      uint256 portion = msg.value.mul(balanceOf[h]).div(totalSupply);
      dividends[h] = dividends[h].add(portion);
      distributed = distributed.add(portion);
    }
    // handle rounding errors
    if (distributed < msg.value && len > 0) {
      dividends[holders[0]] = dividends[holders[0]].add(msg.value.sub(distributed));
    }
  }

  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return dividends[payee];
  }

  function withdrawDividend(address payable dest) external override {
    uint256 amount = dividends[msg.sender];
    require(amount > 0, "nothing to withdraw");
    dividends[msg.sender] = 0;
    dest.transfer(amount);
  }
}