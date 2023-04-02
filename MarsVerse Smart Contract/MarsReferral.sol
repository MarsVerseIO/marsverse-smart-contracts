// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IMC {
    function SolarRate() view external returns (uint256);
}
interface IMA {
}
interface IMD {
    struct AddressReferral {
        uint256[3] balance;
        uint256 first_buy;
        uint256 last_buy;
        bool ban;
        uint256[3] history;
    }

    function update_AddressReferral(address _account, AddressReferral memory _AddressReferral) external;
    function get_AddressReferral(address _address) external view returns (AddressReferral memory);
    function emit_ReferralDeductions(address _account, address _referrer, uint256 _first_buy, uint256 _property_type_id, uint256[3] memory _amount) external;
    function emit_ReferrerPayout(address _referrer, uint256[3] memory _amount) external;
}


contract MarsReferral is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(uint256 => EnumerableSet.AddressSet) _refRequests;
    uint256 private Number;

    constructor(IMC _MarsControl, IMD _MarsData, IMA _MarsAirDrop) {
        MarsControl = _MarsControl;
        MarsData = _MarsData;
        MarsAirDrop = _MarsAirDrop;

        add_level(750, 100000); //[7.5%]  level 0; how much interest will be deducted; maximum level limit (in Solar)
        add_level(900, 200000); //[9%]
        add_level(1000, 300000); //[10%]
    }

    struct LevelData {
        uint256 perc;
        uint256 max_amount;
    }
    mapping (uint256 => LevelData) public LevelDatas;
    uint256 public leveldata_count = 0;

    mapping (address => uint256) public ClaimAmount;

    function add_level(uint256 _perc, uint256 _max_amount) public notContract nonReentrant onlyOwner {
        LevelData memory _LevelData;
        _LevelData.perc = _perc;
        _LevelData.max_amount = _max_amount;
        LevelDatas[leveldata_count] = _LevelData;
        leveldata_count += 1;
    }
    function edit_level(uint256 _index, uint256 _perc, uint256 _max_amount) external notContract nonReentrant onlyOwner {
        LevelData memory _LevelData;
        _LevelData.perc = _perc;
        _LevelData.max_amount = _max_amount;
        LevelDatas[_index] = _LevelData;
    }

    function new_deduction(address _account, address _referrer, uint256 _property_type_id, uint256 _value) external onlyMarsControl {
        if (address(_account) == address(_referrer)) {
            _referrer = address(0);
        }
        IMD.AddressReferral memory _AddressReferral = MarsData.get_AddressReferral(_account);
        uint256[3] memory _amount = [0, _value, 0];
        MarsData.emit_ReferralDeductions(_account, _referrer, _AddressReferral.first_buy, _property_type_id, _amount);
        if (_AddressReferral.first_buy == 0) {
            _AddressReferral.first_buy = block.timestamp;
            _AddressReferral.last_buy = _AddressReferral.first_buy;
            MarsData.update_AddressReferral(_account, _AddressReferral);

            if (_referrer != address(0)) {
                IMD.AddressReferral memory _AddressReferrer = MarsData.get_AddressReferral(_referrer);
                _AddressReferrer.balance[1] += _value;
                MarsData.update_AddressReferral(_referrer, _AddressReferrer);
            }
        }
    }

    function new_deductionAirDrop(address _account, address _referrer, uint256 _property_type_id, uint256 _value) external onlyMarsAirDrop {
        if (address(_account) == address(_referrer)) {
            _referrer = address(0);
        }
        IMD.AddressReferral memory _AddressReferral = MarsData.get_AddressReferral(_account);
        IMD.AddressReferral memory _AddressReferrer = MarsData.get_AddressReferral(_referrer);

        if (_referrer != address(0)) {
            uint256 _percent = LevelDatas[0].perc;
            for (uint i = 0; i < leveldata_count; i++) {
                if (_AddressReferrer.history[1] > LevelDatas[i].max_amount) {
                    _percent = LevelDatas[i].perc;
                }
            }
            _value = _value*_percent/100/100;
        }

        uint256[3] memory _amount = [0, _value, 0];
        MarsData.emit_ReferralDeductions(_account, _referrer, _AddressReferral.first_buy, _property_type_id, _amount);
        
        if (_AddressReferral.first_buy == 0) {
            _AddressReferral.first_buy = block.timestamp;
            _AddressReferral.last_buy = _AddressReferral.first_buy;
            MarsData.update_AddressReferral(_account, _AddressReferral);

            if (_referrer != address(0)) {
                _AddressReferrer.balance[1] += _value;
                _AddressReferrer.history[1] += _value;
                MarsData.update_AddressReferral(_referrer, _AddressReferrer);
            }
        }
    }

    function get_LevelDatas() external view returns (LevelData[] memory) {
        LevelData[] memory _LevelDatas = new LevelData[](leveldata_count);
        for (uint i = 0; i < leveldata_count; i++) {
            _LevelDatas[i] = LevelDatas[i];
        }
        return (_LevelDatas); 
    }

    function up_level_referrer(address _referrer, uint256 level_index) external notContract nonReentrant onlyOwner {
        IMD.AddressReferral memory _AddressReferrer = MarsData.get_AddressReferral(_referrer);
        require (LevelDatas[level_index].perc > 0);
        _AddressReferrer.history[1] = LevelDatas[level_index].max_amount+1;
        MarsData.update_AddressReferral(_referrer, _AddressReferrer);
    }
    
    function referrer_payout_request() external notContract nonReentrant {
        IMD.AddressReferral memory _AddressReferrer = MarsData.get_AddressReferral(msg.sender);
        require (_AddressReferrer.balance[1] > 0 && _AddressReferrer.ban == false);
        if (!_refRequests[Number].contains(msg.sender)) {
            _refRequests[Number].add(msg.sender);
            ClaimAmount[msg.sender] = _AddressReferrer.balance[1];
        }
    }

    function ban_referrer(address _referrer) external notContract nonReentrant onlyOwner {
        IMD.AddressReferral memory _AddressReferrer = MarsData.get_AddressReferral(_referrer);
        _AddressReferrer.ban = true;
        MarsData.update_AddressReferral(_referrer, _AddressReferrer);
        if (_refRequests[Number].contains(_referrer)) {
            _refRequests[Number].remove(_referrer);
            ClaimAmount[_referrer] = 0;
        }
    }

    function cancel_referrer_request(address _referrer) external notContract nonReentrant onlyOwner {
        if (_refRequests[Number].contains(_referrer)) {
            _refRequests[Number].remove(_referrer);
            ClaimAmount[_referrer] = 0;
        }
    }
    function check_referrer_request(address _referrer) external view returns (bool) {
        return _refRequests[Number].contains(_referrer);
    }

    function get_referrer_requests(uint256 size) external view returns (address[] memory, IMD.AddressReferral[] memory) {
       uint256 length = size;
        if (length > _refRequests[Number].length()) {
            length = _refRequests[Number].length();
        }
        address[] memory _referrer_addresses = new address[](length);
        IMD.AddressReferral[] memory _AddressReferrer = new IMD.AddressReferral[](length);
        for (uint256 i = 0; i < length; i++) {
            address _address = _refRequests[Number].at(i);
            _referrer_addresses[i] = _address;
            _AddressReferrer[i] = MarsData.get_AddressReferral(_address);
        }
        return (_referrer_addresses, _AddressReferrer);
    }

    function pay_deductions(uint256 size) external notContract nonReentrant onlyOwner () {
       uint256 length = size;
        if (length > _refRequests[Number].length()) {
            length = _refRequests[Number].length();
        }
        for (uint256 i = 0; i < length; i++) {
            address _address = _refRequests[Number].at(i);
            IMD.AddressReferral memory _AddressReferrer = MarsData.get_AddressReferral(_address);
            uint256 inBNB = ClaimAmount[_address]*MarsControl.SolarRate();
            payable(_address).transfer(inBNB);
            MarsData.emit_ReferrerPayout(_address, [0, ClaimAmount[_address], 0]);
            _AddressReferrer.balance[1] -= ClaimAmount[_address];
            ClaimAmount[_address] = 0;
            MarsData.update_AddressReferral(_address, _AddressReferrer);
        }
        Number += 1;
    }

    function clear_first_pay(address _address) external onlyOwner {
        IMD.AddressReferral memory _AddressReferral = MarsData.get_AddressReferral(_address);
        _AddressReferral.first_buy = 0;
        MarsData.update_AddressReferral(_address, _AddressReferral);
    }

    function topup() external payable notContract nonReentrant {
        require (msg.value > 0);
    }

    function WithdrawalFromTheContract() external onlyOwner {
        payable(address(msg.sender)).transfer(address(this).balance);
    }

    IMC public MarsControl;
    function setAddressMarsControl(IMC _MarsControl) external onlyOwner {
        MarsControl = _MarsControl;
    }
    modifier onlyMarsControl() {
        require(msg.sender == address(MarsControl), "Not MarsControl");
        _;
    }
    ///
    IMD public MarsData;
    function setAddressMarsData(IMD _MarsData) external onlyOwner {
        MarsData = _MarsData;
    }
    ///
    IMA public MarsAirDrop;
    function setAddressMarsAirDrop(IMA _MarsAirDrop) external onlyOwner {
        MarsAirDrop = _MarsAirDrop;
    }
    modifier onlyMarsAirDrop() {
        require(msg.sender == address(MarsAirDrop), "Not MarsAirDrop");
        _;
    }
    ///
    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}