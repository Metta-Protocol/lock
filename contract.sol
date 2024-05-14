// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts@5.0.1/access/Ownable.sol";
import "@openzeppelin/contracts@5.0.1/token/ERC20/extensions/ERC20Burnable.sol";

contract LockMetta is Ownable {
    ERC20Burnable public mettaToken;

    struct Shareholder {
        uint id;
        address shareholderAddress;
        uint shareAmount;
        uint lockTime;
    }

    uint minimumLockTime = 2 * 365 days;
    uint lockStartTime;
    uint shareholderCount;
    uint burnedAmount;

    mapping(address => Shareholder) public shareholders;

    event ShareholderRegistered(address indexed shareholderAddress, uint lockTime, uint shareAmount);
    event TransferBetweenShareholders(address indexed from, address indexed to, uint amount);
    event Withdrawal(address indexed shareholderAddress, uint amount);
    event LockTimeUpdated(address indexed shareholderAddress, uint newLockTime);
    event TokensBurned(address indexed shareholderAddress, uint amount);
    event LockStartTimeSet(uint timestamp);

    constructor(address initialOwner, address mettaTokenAddress) Ownable(initialOwner) {
        mettaToken = ERC20Burnable(mettaTokenAddress);
    }

    function registerShareholder(address _shareHolderAddress, uint _lockTime, uint _shareAmount) external onlyOwner {
        require(_lockTime >= minimumLockTime, "Lock time cannot be lower than minimum lock time");
        shareholderCount++;
        shareholders[_shareHolderAddress] = Shareholder({
            id: shareholderCount,
            shareholderAddress: _shareHolderAddress,
            shareAmount: _shareAmount,
            lockTime: _lockTime
        });
        emit ShareholderRegistered(_shareHolderAddress, _lockTime, _shareAmount);
    }

    function transferToShareholder(address _destShareHolder, uint _amount) external onlyShareholder(msg.sender) onlyShareholder(_destShareHolder) {
        require(shareholders[msg.sender].shareAmount >= _amount, "Not enough token balance");
        shareholders[msg.sender].shareAmount -= _amount;
        shareholders[_destShareHolder].shareAmount += _amount;
        emit TransferBetweenShareholders(msg.sender, _destShareHolder, _amount);
    }

    function withdraw(uint amount) external onlyShareholder(msg.sender) {
        uint lockOpeningTime = lockStartTime + shareholders[msg.sender].lockTime;
        require(block.timestamp >= lockOpeningTime, "Lock time is not ended yet");
        shareholders[msg.sender].shareAmount -= amount;
        require(mettaToken.transfer(msg.sender, amount), "Transfer failed");
        emit Withdrawal(msg.sender, amount);
    }

    function updateLockTimeOfShareholder(address _shareHolderAddress, uint _newLockTime) external onlyOwner {
        require(_newLockTime >= shareholders[_shareHolderAddress].lockTime, "New lock time cannot be lower than previous lock time");
        shareholders[_shareHolderAddress].lockTime = _newLockTime;
        emit LockTimeUpdated(_shareHolderAddress, _newLockTime);
    }

    function burnLockedTokens(uint _amount) external onlyShareholder(msg.sender) {
        mettaToken.burn(_amount);
        burnedAmount += _amount;
        emit TokensBurned(msg.sender, _amount);
    }

    function startLockTime() external onlyOwner {
        require(lockStartTime == 0, "Already locked");
        lockStartTime = block.timestamp;
        emit LockStartTimeSet(block.timestamp);
    }

    function viewShareholder(address _shareHolderAddress) public view returns(Shareholder memory) {
        return shareholders[_shareHolderAddress];
    }
    
    function viewBurnedAmount() public view returns(uint) {
        return burnedAmount;
    }

    function lockedAmount() public view returns(uint) {
        return mettaToken.balanceOf(address(this));
    }

    function totalShareholders() public view returns (uint) {
        return shareholderCount;
    }

    function getMinimumLockTime() public view returns (uint) {
        return minimumLockTime;
    }

    function getLockEndTime(address _shareHolderAddress) public view returns (uint) {
        return lockStartTime + shareholders[_shareHolderAddress].lockTime;
    }

    function getLockedSharesAmount(address _shareHolderAddress) public view returns (uint) {
        return shareholders[_shareHolderAddress].shareAmount;
    }

    function getLockStartTime() public view returns (uint) {
        return lockStartTime;
    }

    modifier onlyShareholder(address _shareHolderAddress) {
        require(shareholders[_shareHolderAddress].id != 0, "Not a shareholder");
        _;
    }
}
