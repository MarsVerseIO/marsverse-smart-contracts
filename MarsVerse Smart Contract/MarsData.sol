// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract MarsData is ERC1155, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor() ERC1155("http://localhost/api/{id}.json") {
    
    }

    uint256 public constant SOLAR = 1;
    uint256 public constant PROVISION = 2;

    uint256 public Day = 0;
    uint256[2] MarsTotalPower;
    EnumerableSet.AddressSet _active;

    struct AddressPower {
        uint256[3] power;
        uint256 need_solar;
        uint256 frozen_provision;
    }
    mapping (address => AddressPower) AddressPowers;

    struct AddressFinance {
        uint256[3] balance;
        uint256 solar_tank;
    }
    mapping (address => AddressFinance) AddressFinances;

    struct AddressReferral {
        uint256[3] balance;
        uint256 first_buy;
        uint256 last_buy;
        bool ban;
        uint256[3] history;
    }
    mapping (address => AddressReferral) AddressReferrals;

    struct Limit {
        uint256 mining_limit;
        uint256 staking_limit;
    }
    Limit public Limits;

    // Recover ERC20 tokens sent by accident
    event TokenRecovery(address indexed token, uint256 amount);
    // Recover NFT tokens sent by accident
    event NonFungibleTokenRecovery(address indexed token, uint256 indexed tokenId);

    event AutoTake(uint256 indexed day, Limit limit, uint256[2] totalpower);
    event AutoTakeUser(uint256 indexed day, address indexed account, AddressPower _AP);
    event ReferralDeductions(address indexed account, address indexed referrer, uint256 indexed first_buy, uint256 property_type_id, uint256[3] amount);
    event ReferrerPayout(address indexed referrer, uint256[3] amount);

    function emit_AutoTake(uint256 _Day, Limit memory _Limit, uint256[2] memory _totalpower) external onlyMarsControl {
        emit AutoTake(_Day, _Limit, _totalpower);
    }
    function emit_AutoTakeUser(uint256 _Day, address _address, AddressPower memory _AddressPower) external onlyMarsControl {
        emit AutoTakeUser(_Day, _address, _AddressPower);
    }
    function emit_ReferralDeductions(address _account, address _referrer, uint256 _first_buy, uint256 _property_type_id, uint256[3] memory _amount) external onlyMarsReferral {
        emit ReferralDeductions(_account, _referrer, _first_buy, _property_type_id, _amount);
    }
    function emit_ReferrerPayout(address _referrer, uint256[3] memory _amount) external onlyMarsReferral {
        emit ReferrerPayout(_referrer, _amount);
    }

    //////////////////////////////////////////////////////////
    function burn_solar(address _account, uint _amount) external onlyMarsControl {
        require (balanceOf(_account, SOLAR) >= _amount, "Not enough solar");
        _burn(_account, SOLAR, _amount);
    }

    function mint_solar(address _account, uint _amount) external onlyMarsControl {
        _mint(_account, SOLAR, _amount, "");
    }

    function burn_provision(address _account, uint _amount) external onlyMarsControl {
        require (balanceOf(_account, PROVISION) >= _amount, "Not enough provision");
        _burn(_account, PROVISION, _amount);
    }
    function mint_provision(address _account, uint _amount) external onlyMarsControl {
        _mint(_account, PROVISION, _amount, "");
    }

    function add_Day() external onlyMarsControl {
        Day += 1;
    }
    function add_MarsTotalPower(uint256 _index, uint256 _value) external onlyMarsControl {
        require (_index == 0 || _index == 1);
        MarsTotalPower[_index] += _value;
    }
    function sub_MarsTotalPower(uint256 _index, uint256 _value) external onlyMarsControl {
        require (_index == 0 || _index == 1);
        MarsTotalPower[_index] -= _value;
    }
    function update_AddressPower(address _account, AddressPower memory _AddressPower) external onlyMarsControl {
        if (AddressPowers[_account].need_solar != _AddressPower.need_solar) AddressPowers[_account].need_solar = _AddressPower.need_solar;
        if (AddressPowers[_account].frozen_provision != _AddressPower.frozen_provision) AddressPowers[_account].frozen_provision = _AddressPower.frozen_provision;
        if (AddressPowers[_account].power[0] != _AddressPower.power[0] || AddressPowers[_account].power[1] != _AddressPower.power[1] || AddressPowers[_account].power[2] != _AddressPower.power[2]) AddressPowers[_account].power = _AddressPower.power;
    }
    function update_AddressFinance(address _account, AddressFinance memory _AddressFinance) external onlyMarsControl {
        if (AddressFinances[_account].solar_tank != _AddressFinance.solar_tank) AddressFinances[_account].solar_tank = _AddressFinance.solar_tank;
        if (AddressFinances[_account].balance[0] != _AddressFinance.balance[0] || AddressFinances[_account].balance[1] != _AddressFinance.balance[1] || AddressFinances[_account].balance[2] != _AddressFinance.balance[2]) AddressFinances[_account].balance = _AddressFinance.balance;
    }
    function update_AddressReferral(address _account, AddressReferral memory _AddressReferral) external onlyMarsReferral {
        AddressReferrals[_account] = _AddressReferral;
    }
    function update_Limits(Limit memory _Limit) external onlyMarsControl {
        Limits = _Limit;
    }
    ////////////////////////////////////////////////////////////////////////

    function get_MarsTotalPower() external view returns (uint[2] memory) {
        return MarsTotalPower;
    }

    function get_AddressPower(address _address) external view returns (AddressPower memory) {
        return AddressPowers[_address];
    }

    function get_AddressFinance(address _address) external view returns (AddressFinance memory) {
        return AddressFinances[_address];
    }

    function get_AddressReferral(address _address) external view returns (AddressReferral memory) {
        return AddressReferrals[_address];
    }
    function get_Limits() external view returns (Limit memory) {
        return Limits;
    }

    function active_add(address _address) external onlyMarsControl returns (bool) {
        return _active.add(_address);
    }
    function active_remove(address _address) external onlyMarsControl returns (bool) {
        return _active.remove(_address);
    }
    function active_contains(address _address) external view returns (bool) {
        return _active.contains(_address);
    }
    function active_length() external view returns (uint256) {
        return _active.length();
    }
    function active_at(uint256 _index) external view returns (address) {
        return _active.at(_index);
    }
    /////////////////////////////////////////////////////////////////////////



    function WithdrawalFromTheContract() external onlyOwner {
        payable(address(msg.sender)).transfer(address(this).balance);
    }


    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    /**
     * @notice Allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @dev Callable by owner
     */
    function recoverFungibleTokens(address _token) external onlyOwner {
        uint256 amountToRecover = IERC20(_token).balanceOf(address(this));
        require(amountToRecover != 0, "No token to recover");

        IERC20(_token).safeTransfer(address(msg.sender), amountToRecover);

        emit TokenRecovery(_token, amountToRecover);
    }

    /**
     * @notice Allows the owner to recover NFTs sent to the contract by mistake
     * @param _token: NFT token address
     * @param _tokenId: tokenId
     * @dev Callable by owner
     */
    function recoverNonFungibleToken(address _token, uint256 _tokenId) external onlyOwner nonReentrant {
        IERC721(_token).safeTransferFrom(address(this), address(msg.sender), _tokenId);
        emit NonFungibleTokenRecovery(_token, _tokenId);
    }

    ///
    address public MarsControl;
    function setAddressMarsControl(address _MarsControl) external onlyOwner {
        require(_MarsControl != address(0), "not0");
        MarsControl = _MarsControl;
    }
    modifier onlyMarsControl() {
        require(msg.sender == MarsControl, "Not MarsControl");
        _;
    }
    ///
    address public MarsReferral;
    function setAddressMarsReferral(address _MarsReferral) external onlyOwner {
        require(_MarsReferral != address(0), "not0");
        MarsReferral = _MarsReferral;
    }
    modifier onlyMarsReferral() {
        require(msg.sender == MarsReferral, "Not MarsReferral");
        _;
    }
    ///

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

}