// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IMC {
    function airdrop_polygon(address _address, uint _x, uint _y) external;
    function airdrop_property(uint _property_type_id, uint _polygon_id, uint _level) external;
    function airdrop_fill_tank(address _address, uint _amount) external;
    function update_power_Ex(address account) external;
    function SolarRate() view external returns (uint256);
}
interface IMR {
    function new_deductionAirDrop(address _account, address _referrer, uint256 _property_type_id, uint256 _value) external;
}
interface IMD {
}

interface IMO {
    struct Polygoninfo {
        address account;
        uint256 x; 
        uint256 y;
        uint256 propertys_count;
    }
    function Polygon(uint key) view external returns (Polygoninfo memory);
    function polygon_count() view external returns (uint256);

    struct PropertyTypeinfo {
        uint256[3] power;
        uint256 discount;
        bool exist;
    }
    function get_PropertyType(uint key) view external returns (PropertyTypeinfo memory);
    function get_MapSize() external view returns (uint[2] memory);
}


contract MarsAirDrop is Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet _refRequests;

    constructor(IMO _MarsObject, IMD _MarsData, IMC _MarsControl, IMR _MarsReferral) {
        MarsObject = _MarsObject;
        MarsData = _MarsData;
        MarsControl = _MarsControl;
        MarsReferral = _MarsReferral;

        StartTime = block.timestamp;

        add_stage(60*60*24*30);
        add_stage(60*60*24*30);
        add_stage(60*60*24*30);

        add_package(0, 0, 30, 1);
        add_package(0, 0, 60, 2);
        add_package(0, 0, 90, 3);
        add_package(0, 0, 120, 4);
        add_package(0, 0, 300, 10);

        add_package(1, 7, 30, 1);
        add_package(1, 7, 60, 2);
        add_package(1, 7, 90, 3);
        add_package(1, 7, 120, 4);
        add_package(1, 7, 300, 10);

        add_package(2, 14, 30, 1);
        add_package(2, 14, 60, 2);
        add_package(2, 14, 90, 3);
        add_package(2, 14, 120, 4);
        add_package(2, 14, 300, 10);
    }

    event NewBuy(address indexed _address, address indexed _referrer, uint256 _stage, uint256 _package_id, uint256 _polygon_id, uint256 _price_inBNB, uint256 _battery_charge, uint256 _battery_charge_inSolar);

    struct Package {
        uint256 stage;
        uint256 property_type_id;
        uint256 days_receive_tokens;
        uint256 level;
    }
    mapping (uint256 => Package) public Packages;
    uint256 public package_count;

    uint256 public StartTime;

    struct Stage {
        uint256 duration;
    }
    mapping (uint256 => Stage) public Stages;
    uint256 public stage_count;

    function get_current_stage() public view returns(uint256) {
        uint256 _temp_time = StartTime;
        for (uint i = 0; i < stage_count; i++) {
            _temp_time += Stages[i].duration;
            if (_temp_time > block.timestamp) {
                return i;
            }
        }
        return stage_count;
    }
    function add_stage(uint256 _duration) private {
        Stages[stage_count].duration = _duration;
        stage_count += 1;
    }
    function add_new_stage(uint256 _duration) external notContract nonReentrant onlyOwner {
        add_stage(_duration);
    }
    function edit_stage(uint256 _index, uint256 _duration) external notContract nonReentrant onlyOwner {
        Stages[_index].duration = _duration;
    } 

    function get_Stages() external view returns (Stage[] memory) {
        Stage[] memory _Stages = new Stage[](stage_count);
        for (uint i = 0; i < stage_count; i++) {
            _Stages[i] = Stages[i];
        }
        return (_Stages);
    }

    function add_package(uint256 _stage, uint256 _property_type_id, uint256 _days_receive_tokens, uint256 _level) private {
        Packages[package_count].stage = _stage;
        Packages[package_count].property_type_id = _property_type_id;
        Packages[package_count].days_receive_tokens = _days_receive_tokens;
        Packages[package_count].level = _level;
        package_count += 1;
    }
    function add_new_package(uint256 _stage, uint256 _property_type_id, uint256 _days_receive_tokens, uint256 _level) external notContract nonReentrant onlyOwner {
        add_package(_stage, _property_type_id, _days_receive_tokens, _level);
    }
    function edit_package(uint _index, uint256 _stage, uint256 _property_type_id, uint256 _days_receive_tokens, uint256 _level) external notContract nonReentrant onlyOwner {
        require (_index < package_count);
        Packages[_index].stage = _stage;
        Packages[_index].property_type_id = _property_type_id;
        Packages[_index].days_receive_tokens = _days_receive_tokens;
        Packages[_index].level = _level;
    }


    function get_Packages() external view returns (Package[] memory, uint256[] memory) {
        Package[] memory _Packages = new Package[](package_count);
        uint256[] memory _price_inBNB = new uint256[](package_count);
        for (uint i = 0; i < package_count; i++) {
            _Packages[i] = Packages[i];
            (_price_inBNB[i], , ) = get_price_package(Packages[i].property_type_id, Packages[i].level, Packages[i].days_receive_tokens);
        }
        return (_Packages, _price_inBNB);
    }

    function get_price_package(uint256 _property_type_id, uint256 _level, uint256 _days_receive_tokens) public view returns(uint256, uint256, uint256) {
        uint256 _consumption_min30d = (MarsObject.get_PropertyType(0).power[0]*100/80)*MarsControl.SolarRate()*30;
        uint256 _coef_power=MarsObject.get_PropertyType(_property_type_id).power[0]/MarsObject.get_PropertyType(0).power[0]*_level;
        uint256 _price30d = _coef_power*_consumption_min30d;
        uint256 _battery_charge = _price30d*(_days_receive_tokens/30);
        uint256 _battery_charge_inSolar = _battery_charge/MarsControl.SolarRate();
        uint256 _result_price_inBNB = _price30d+_battery_charge;
        return (_result_price_inBNB, _battery_charge, _battery_charge_inSolar);
    }
    
    function buy_airdrop(uint256 _package_id, address _referrer) external payable notContract nonReentrant {
        (uint256 _price_inBNB, uint256 _battery_charge, uint256 _battery_charge_inSolar) = get_price_package(Packages[_package_id].property_type_id, Packages[_package_id].level, Packages[_package_id].days_receive_tokens);
        require (msg.value == _price_inBNB);
        require (Packages[_package_id].stage == get_current_stage());
        uint256[2] memory _MapSize = MarsObject.get_MapSize();
        MarsControl.airdrop_polygon(msg.sender, random(_MapSize[0]), random(_MapSize[1]));
        uint256 _polygon_id = MarsObject.polygon_count()-1;
        MarsControl.airdrop_property(Packages[_package_id].property_type_id, _polygon_id, Packages[_package_id].level);
        MarsControl.airdrop_fill_tank(msg.sender, _battery_charge_inSolar);
        MarsControl.update_power_Ex(msg.sender);
        if (address(msg.sender) == address(_referrer)) {
            _referrer = address(0);
        }
        emit NewBuy(msg.sender, _referrer, Packages[_package_id].stage, _package_id, _polygon_id, _price_inBNB, _battery_charge, _battery_charge_inSolar);
        MarsReferral.new_deductionAirDrop(msg.sender, _referrer, Packages[_package_id].property_type_id, _battery_charge_inSolar);
    }

    uint256 private nonce;
    function random(uint256 _max) internal returns (uint) {
        uint randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % _max;
        nonce++;
        return randomnumber;
    }


    function airdrop_polygon(address _address, uint _x, uint _y) external notContract nonReentrant onlyOwner {
        MarsControl.airdrop_polygon(_address, _x, _y);
    }
    function airdrop_property(uint _property_type_id, uint _polygon_id, uint _level) external notContract nonReentrant onlyOwner {
        MarsControl.airdrop_property(_property_type_id, _polygon_id, _level);
        MarsControl.update_power_Ex(MarsObject.Polygon(_polygon_id).account);
    }

    function airdrop_full(address _address, uint _x, uint _y, uint _property_type_id, uint _level) external notContract nonReentrant onlyOwner {
        MarsControl.airdrop_polygon(_address, _x, _y);
        uint256 _polygon_id = MarsObject.polygon_count()-1;
        MarsControl.airdrop_property(_property_type_id, _polygon_id, _level);
        MarsControl.update_power_Ex(MarsObject.Polygon(_polygon_id).account);
    }

    function airdrop_full_array(address[] memory _address, uint[] memory _x, uint[] memory _y, uint[] memory _property_type_id, uint[] memory _level) external notContract nonReentrant onlyOwner {
        for (uint i = 0; i < _address.length; i++) {
            MarsControl.airdrop_polygon(address(_address[i]), _x[i], _y[i]);
            uint256 _polygon_id = MarsObject.polygon_count()-1;
            MarsControl.airdrop_property(_property_type_id[i], _polygon_id, _level[i]);
            MarsControl.update_power_Ex(MarsObject.Polygon(_polygon_id).account);
        }
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
    IMO public MarsObject;
    function setAddressMarsObject(IMO _MarsObject) external onlyOwner {
        MarsObject = _MarsObject;
    }
    ///
    IMD public MarsData;
    function setAddressMarsData(IMD _MarsData) external onlyOwner {
        MarsData = _MarsData;
    }
    ///
    IMR public MarsReferral;
    function setAddressMarsReferral(IMR _MarsReferral) external onlyOwner {
        MarsReferral = _MarsReferral;
    }
    modifier onlyMarsReferral() {
        require(msg.sender == address(MarsReferral), "Not MarsReferral");
        _;
    }
    //
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