// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20Meta is IERC20 {
    function mint_operator(address to, uint256 amount, uint256 reason) external;
    function get_DailyDistribution() external returns (uint256);
}
interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}
interface IPOOLCHEF {
    function updatePool(uint256 cakeReward) external;
}
interface IMO {

    struct PropertyTypeinfo {
        uint256[3] power;
        uint256 discount;
        bool exist;
    }
    function get_PropertyType(uint key) view external returns (PropertyTypeinfo memory);

    struct Polygoninfo {
        address account;
        uint256 x; 
        uint256 y;
        uint256 propertys_count;
    }
    function Polygon(uint key) view external returns (Polygoninfo memory);
    function polygon_count() view external returns (uint256);

    struct Propertyinfo {
        uint256 polygon_id;
        uint256 property_type_id;
        uint256 level;
    }
    function Property(uint key) view external returns (Propertyinfo memory);


    function get_account_power_Ex(address _address) external view returns (uint[] memory);
    function get_distance(int _x1, int _y1, int _x2, int _y2) external pure returns (uint256);
    function add_polygon_Ex(address _account, uint256 _x, uint256 _y) external;
    function add_property_Ex(uint _property_type_id, uint _polygon_id, uint _level) external;
    function property_level_up_Ex(address _account, uint256 _property_id) external;
}
interface IMD {
    struct AddressPower {
        uint256[3] power;
        uint256 need_solar;
        uint256 frozen_provision;
    }
    struct AddressFinance {
        uint256[3] balance;
        uint256 solar_tank;
    }
    struct Limit {
        uint256 mining_limit;
        uint256 staking_limit;
    }

    function burn_solar(address _account, uint _amount) external;
    function mint_solar(address _account, uint _amount) external;
    function burn_provision(address _account, uint _amount) external;
    function mint_provision(address _account, uint _amount) external;
    function Day() view external returns (uint256);
    function add_Day() external;
    function add_MarsTotalPower(uint256 _index, uint256 _value) external;
    function sub_MarsTotalPower(uint256 _index, uint256 _value) external;
    function update_AddressPower(address _account, AddressPower memory _AddressPower) external;
    function update_AddressFinance(address _account, AddressFinance memory _AddressFinance) external;
    function get_MarsTotalPower() external view returns (uint[2] memory);
    function get_AddressPower(address _address) external view returns (AddressPower memory);
    function get_AddressFinance(address _address) external view returns (AddressFinance memory);
    function active_add(address _address) external returns (bool);
    function active_remove(address _address) external returns (bool);
    function active_contains(address _address) external view returns (bool);
    function active_length() external view returns (uint256);
    function active_at(uint256 _index) external view returns (address);
    function get_Limits() external view returns (Limit memory);
    function update_Limits(Limit memory _Limit) external;
    function emit_AutoTake(uint256 _Day, Limit memory _Limit, uint256[2] memory _totalpower) external;
    function emit_AutoTakeUser(uint256 _Day, address _address, AddressPower memory _AddressPower) external;
}
interface IMR {
    function new_deduction(address _account, address _referrer, uint256 _property_type_id, uint256 _amount) external;
}
interface IMA {

}

contract MarsControl is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20Meta;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(IERC20Meta _MarsToken,
            IMO _MarsObject,
            IMD _MarsData,
            address _AdminAddress,
            address _MarsBot,
            uint256 _SolarRate,
            uint256 _SolarPriceIfZero,
            uint256 _NeighboursRange,
            uint256 _MinPricePolygon,
            uint256 _CoefPrice) {
        MarsToken = _MarsToken;
        MarsObject = _MarsObject;
        MarsData = _MarsData;
        AdminAddress = _AdminAddress;
        MarsBot = _MarsBot;
        SolarRate = _SolarRate;     
        SolarPriceIfZero = _SolarPriceIfZero;
        NeighboursRange = _NeighboursRange;
        MinPricePolygon = _MinPricePolygon;
        CoefPrice = _CoefPrice;
    }

    uint256 public SolarRate; //rate 1 solar = 100000000000 Wei (0,00001 ETH)

    uint256 public StakingMintPercent = 80;
    uint256 public SolarPriceIfZero;
    uint256 public IfCrystalPowerZero = 1;
    uint256 public DaysReturnSolar = 3;

    mapping(uint256 => EnumerableSet.AddressSet) _rem;

    uint256 public LastTimeTake;
    uint256 public LastTimeAfterTake;
    uint256 Cursor;
    uint256 CursorAfter;

    uint256[2] CacheMarsTotalPower;

    // Recover ERC20 tokens sent by accident
    event TokenRecovery(address indexed token, uint256 amount);
    // Recover NFT tokens sent by accident
    event NonFungibleTokenRecovery(address indexed token, uint256 indexed tokenId);

    event UpdatePower(address indexed _address);

    function buy_solar() external payable notContract nonReentrant {
        uint256 _amount = msg.value/SolarRate;
        require (_amount > 0);
        MarsData.mint_solar(msg.sender, _amount);
    }
    function airdrop_fill_tank(address _address, uint256 _solar) external onlyMarsAirDrop {
        require (_solar > 0);
        IMD.AddressFinance memory _AddressFinance = MarsData.get_AddressFinance(_address);
        _AddressFinance.solar_tank += _solar;
        MarsData.update_AddressFinance(_address, _AddressFinance);
    }

    function fill_tank(uint256 _solar) external notContract nonReentrant {
        MarsData.burn_solar(msg.sender, _solar);
        IMD.AddressFinance memory _AddressFinance = MarsData.get_AddressFinance(msg.sender);
        _AddressFinance.solar_tank += _solar;
        MarsData.update_AddressFinance(msg.sender, _AddressFinance);
        update_power(msg.sender);
    }

    function use_provisions(uint _amount) external notContract nonReentrant {
        require (_amount > 0 , "Amount can not be 0");
        IMD.AddressPower memory _AddressPower = MarsData.get_AddressPower(msg.sender);
        require (_AddressPower.frozen_provision == 0 , "#238");
        MarsData.burn_provision(msg.sender, _amount);
        _AddressPower.frozen_provision = _amount;
        MarsData.update_AddressPower(msg.sender, _AddressPower);
        update_power(msg.sender);
    }
    function cansel_use_provisions() external notContract nonReentrant {
        IMD.AddressPower memory _AddressPower = MarsData.get_AddressPower(msg.sender);
        require (_AddressPower.frozen_provision > 0 , "No unused provisions");
        MarsData.mint_provision(msg.sender, _AddressPower.frozen_provision);
        _AddressPower.frozen_provision = 0;
        MarsData.update_AddressPower(msg.sender, _AddressPower);
        update_power(msg.sender);
    }
    function Take() external notContract nonReentrant {
        IMD.AddressFinance memory _AddressFinance = MarsData.get_AddressFinance(msg.sender);
        if (_AddressFinance.balance[0] > 0) {
            MarsToken.mint_operator(address(msg.sender), _AddressFinance.balance[0], 0);
            _AddressFinance.balance[0] = 0;
        }
        if (_AddressFinance.balance[1] > 0) {
            MarsData.mint_solar(msg.sender, _AddressFinance.balance[1]);
            _AddressFinance.balance[1] = 0;
        }
        if (_AddressFinance.balance[2] > 0) {
            MarsData.mint_provision(msg.sender, _AddressFinance.balance[2]);
            _AddressFinance.balance[2] = 0;
        }
        MarsData.update_AddressFinance(msg.sender, _AddressFinance);
    }

    function update_power(address _address) private {
        require (Cursor == 0, "Wait for the calculation to complete");

        uint[] memory _sum_powers = new uint[](3);
        _sum_powers = MarsObject.get_account_power_Ex(_address);

        IMD.AddressPower memory _AddressPower = MarsData.get_AddressPower(_address);

        if (_AddressPower.frozen_provision > 0) {
            _sum_powers[0] += _AddressPower.frozen_provision;
        }

        uint solar_take = _sum_powers[0]*100/StakingMintPercent;

        if (_sum_powers[0] == 0 && _sum_powers[1]+_sum_powers[2] > 0) {
            _AddressPower.need_solar = IfCrystalPowerZero;
        } else {
            _AddressPower.need_solar = solar_take;
        }
        IMD.AddressFinance memory _AddressFinance = MarsData.get_AddressFinance(_address);
        if (_AddressFinance.solar_tank >= _AddressPower.need_solar && _sum_powers[0]+_sum_powers[1]+_sum_powers[2] > 0) {
    
            if(!MarsData.active_contains(_address)) {
                MarsData.active_add(_address);

                MarsData.add_MarsTotalPower(0, _sum_powers[0]);
                MarsData.add_MarsTotalPower(1, _sum_powers[1]);

            } else {
                MarsData.sub_MarsTotalPower(0, _AddressPower.power[0]);
                MarsData.sub_MarsTotalPower(1, _AddressPower.power[1]);
                MarsData.add_MarsTotalPower(0, _sum_powers[0]);
                MarsData.add_MarsTotalPower(1, _sum_powers[1]);
            }
        } else {
            if(MarsData.active_contains(_address)) {
                MarsData.active_remove(_address);
                MarsData.sub_MarsTotalPower(0, _AddressPower.power[0]);
                MarsData.sub_MarsTotalPower(1, _AddressPower.power[1]);
            }
        }

        _AddressPower.power = [_sum_powers[0], _sum_powers[1], _sum_powers[2]];
        MarsData.update_AddressPower(_address, _AddressPower);
        emit UpdatePower(_address);
    }

    function update_power_Ex(address _address) external onlyMars {
        update_power(_address);
    }

    function update_limit() private {
            uint256 _limit = MarsToken.get_DailyDistribution();
            IMD.Limit memory _Limit;
            _Limit.mining_limit = _limit*StakingMintPercent/100;
            _Limit.staking_limit = _limit-_Limit.mining_limit;
            MarsData.update_Limits(_Limit);
    }
    function startContract() external notContract nonReentrant onlyOwner {
        update_limit();
    }

    function auto_take(uint256 size) external notContract nonReentrant onlyMarsBot {
        if (LastTimeTake+86400 < block.timestamp) {

            if (Cursor == 0) {
                CacheMarsTotalPower = MarsData.get_MarsTotalPower();
                    
            }
            uint256 _Day = MarsData.Day();
            uint256 solar_limit = (CacheMarsTotalPower[0]*100/StakingMintPercent)*10/100;

            uint256 length = size;
            
            if (length > MarsData.active_length() - Cursor) {
                length = MarsData.active_length() - Cursor;
            }
            for (uint256 i = 0; i < length; i++) {
                address _address = MarsData.active_at(Cursor + i);
                IMD.AddressFinance memory _AddressFinance = MarsData.get_AddressFinance(_address);
                IMD.AddressPower memory _AddressPower = MarsData.get_AddressPower(_address);

                _AddressFinance.solar_tank -= _AddressPower.need_solar;
                if (CacheMarsTotalPower[0] != 0) {
                    IMD.Limit memory _Limit = MarsData.get_Limits();
                    uint256 tokens = _AddressPower.power[0] * _Limit.mining_limit / CacheMarsTotalPower[0];
                    _AddressFinance.balance[0] += tokens;
                }
                            
                _AddressFinance.balance[2] += _AddressPower.power[2];
                if (CacheMarsTotalPower[1] != 0) {
                    uint256 solars = _AddressPower.power[1] * solar_limit / CacheMarsTotalPower[1];
                    _AddressFinance.balance[1] += solars;
                }
                MarsData.emit_AutoTakeUser(_Day, _address, _AddressPower);
                if (_AddressPower.frozen_provision > 0) {
                    _AddressPower.power[0] -= _AddressPower.frozen_provision;
                    MarsData.sub_MarsTotalPower(0, _AddressPower.frozen_provision);
                    _AddressPower.need_solar = _AddressPower.power[0]*100/StakingMintPercent;
                    _AddressPower.frozen_provision = 0;
                }
                if (_AddressFinance.solar_tank < _AddressPower.need_solar) {
                    _rem[_Day].add(_address);
                    MarsData.sub_MarsTotalPower(0, _AddressPower.power[0]);
                    MarsData.sub_MarsTotalPower(1, _AddressPower.power[1]);
                }
                MarsData.update_AddressFinance(_address, _AddressFinance);
                MarsData.update_AddressPower(_address, _AddressPower);
            }
            Cursor += length;
            if (Cursor >= MarsData.active_length()) {
                LastTimeTake = block.timestamp-(block.timestamp%86400);
            }
        } else {
            after_take(size);
        }
    }
    
    function after_take(uint256 size) private {
        require (LastTimeAfterTake+86400 < block.timestamp, "Already distributed");
        uint256 _Day = MarsData.Day();
        uint256 length = size;
        if (length > _rem[_Day].length() - CursorAfter) {
            length = _rem[_Day].length() - CursorAfter;
        }
        for (uint256 i = 0; i < length; i++) {
            if (CursorAfter + i < _rem[_Day].length()) {
                address _address = _rem[_Day].at(CursorAfter + i);
                if(MarsData.active_contains(_address)) {
                    MarsData.active_remove(_address);
                }
            }
        }
        CursorAfter += length;
        if (CursorAfter >= _rem[_Day].length()) {
            LastTimeAfterTake = block.timestamp-(block.timestamp%86400);
            Cursor = 0;
            CursorAfter = 0;
            IMD.Limit memory _Limit = MarsData.get_Limits();
            address _mint_address;
            if(address(StakePoolAddress) != address(0)) {
                _mint_address = StakePoolAddress;
            } else {
                _mint_address = AdminAddress;
            }
            MarsToken.mint_operator(address(_mint_address), _Limit.staking_limit, 0);
            MarsData.emit_AutoTake(_Day, _Limit, CacheMarsTotalPower);
            MarsData.add_Day();
            update_limit();
        }
    }



    function get_price_property(uint256 _property_type_id) public view returns (uint, uint, uint, uint) {
        IMO.PropertyTypeinfo memory propertytypeDetail = MarsObject.get_PropertyType(_property_type_id);
        require (propertytypeDetail.exist == true );
        uint256 _tokens_price = 0;
        uint256 _solars_price = propertytypeDetail.power[1];
        uint256 _3day_need_solar = (propertytypeDetail.power[0] + propertytypeDetail.power[2])*DaysReturnSolar*100/StakingMintPercent;

        uint256[2] memory _MarsTotalPower = MarsData.get_MarsTotalPower();
        if (_MarsTotalPower[0] != 0 && _MarsTotalPower[1] != 0) {
            IMD.Limit memory _Limit = MarsData.get_Limits();
            uint256 _dayprice = (propertytypeDetail.power[0] + propertytypeDetail.power[2]) * _Limit.mining_limit / _MarsTotalPower[0];
            _tokens_price = _dayprice*30*propertytypeDetail.discount/100;
        } else {
            _solars_price += SolarPriceIfZero*(propertytypeDetail.power[0] + propertytypeDetail.power[2]);
        }
        _solars_price += _3day_need_solar;

        //ref
        uint256 ref_amount_max = 0;
        if (_tokens_price != 0 && propertytypeDetail.power[1] == 0) {
            ref_amount_max = _solars_price;
        }
        if (_tokens_price != 0 && propertytypeDetail.power[1] != 0) {
            ref_amount_max = (_solars_price-propertytypeDetail.power[1])+(propertytypeDetail.power[1]*10/100);
        }
        if (_tokens_price == 0) {
            ref_amount_max = _solars_price*10/100;
        }

        return (_tokens_price, _solars_price, _3day_need_solar, ref_amount_max); 
    }

    function buy_polygon(uint256 _x, uint256 _y) external payable notContract nonReentrant {
        uint256 _price = get_price_polygon(_x, _y);
        require (msg.value == _price);
        MarsObject.add_polygon_Ex(address(msg.sender), _x, _y);
        update_power(msg.sender);
    }


    function buy_property(uint256 _property_type_id, uint256 _polygon_id, address _referrer) public notContract nonReentrant {
        IMO.PropertyTypeinfo memory propertytypeDetail = MarsObject.get_PropertyType(_property_type_id);
        require (propertytypeDetail.exist == true); 
        require (MarsObject.Polygon(_polygon_id).account == msg.sender, "This polygon does not belong to you"); 
        write_off(msg.sender, _property_type_id, _referrer);
        MarsObject.add_property_Ex(_property_type_id, _polygon_id, 1);
        update_power(msg.sender);
    }

    function property_level_up(uint256 _property_id, address _referrer) external notContract nonReentrant {
        write_off(msg.sender, MarsObject.Property(_property_id).property_type_id, _referrer);
        MarsObject.property_level_up_Ex(msg.sender, _property_id);
        update_power(msg.sender);
    }

    function write_off(address _account, uint256 _property_type_id, address _referrer) private {
        uint[] memory _price = new uint[](4);
        (_price[0], _price[1], _price[2], _price[3]) = get_price_property(_property_type_id);
        MarsData.burn_solar(_account, _price[1]);
        MarsToken.safeTransferFrom(_account, address(this), _price[0]);
        if(ChefPoolAddress != address(0)) {
            IPOOLCHEF(ChefPoolAddress).updatePool(_price[0]);
        } else {
            MarsToken.safeTransfer(AdminAddress, _price[0]);
        }

        IMD.AddressFinance memory _AddressFinance = MarsData.get_AddressFinance(_account);
        _AddressFinance.solar_tank += _price[2];
        MarsData.update_AddressFinance(_account, _AddressFinance);

        MarsReferral.new_deduction(_account, _referrer, _property_type_id, _price[3]);
    }

    ////////////////////////////////////////////////////////////////////////
    function airdrop_polygon(address _address, uint _x, uint _y) external onlyMarsAirDrop {
        MarsObject.add_polygon_Ex(address(_address), _x, _y);
    }

    function airdrop_property(uint _property_type_id, uint _polygon_id, uint _level) external onlyMarsAirDrop {
        MarsObject.add_property_Ex(_property_type_id, _polygon_id, _level);
    }

    ////////////////////////////////////////////////////////////////////////

    function is_active(address _address) public view returns (bool) {
        return MarsData.active_contains(_address);
    }

    function get_price_polygon(uint _x, uint _y) public view returns (uint256) {
        uint256 _ncount = get_neighbours_new(_x, _y);
        uint256 _price = MinPricePolygon+(MinPricePolygon*_ncount/CoefPrice);
        return _price;
    }

    function get_neighbours_new(uint _x, uint _y) public view returns (uint256) {
        uint256 _ncount;
        for (uint i = 0; i < MarsObject.polygon_count(); i++) { 
            IMO.Polygoninfo memory _Polygon = MarsObject.Polygon(i);
            uint distance = MarsObject.get_distance(int(_x), int(_y), int(_Polygon.x), int(_Polygon.y));
            if (NeighboursRange > distance) {
                if(is_active(_Polygon.account)) {
                    _ncount++;
                }
            }
        }
        return _ncount;
    }


    address public AdminAddress;
    IERC20Meta public MarsToken;               // Token ERC20
    address public StakePoolAddress = address(0); // Stake
    address public ChefPoolAddress = address(0); // Farming

    uint256 public NeighboursRange; 
    uint256 public MinPricePolygon;
    uint256 public CoefPrice;            // price coefficient, where 1 is an increase in price by 100% for each guest, 10 is an increase in price by 10% for each guest,, 100 is an increase in price by 1% for each guest


    function setAddress(address _ChefPoolAddress, address _StakePoolAddress, address _AdminAddress) external onlyOwner {
        require(_AdminAddress != address(0), "not0");
        ChefPoolAddress = _ChefPoolAddress;
        StakePoolAddress = _StakePoolAddress;
        AdminAddress = _AdminAddress;
    }
    function setChefPoolApprove() external onlyOwner {
        MarsToken.safeApprove(address(ChefPoolAddress), type(uint256).max);
    }

    function setSettings(uint256 _SolarRate, uint256 _SolarPriceIfZero, uint256 _IfCrystalPowerZero, uint256 _DaysReturnSolar) external onlyOwner {
        require(_SolarRate != 0 && _SolarPriceIfZero != 0 && _IfCrystalPowerZero != 0, "not0");
        SolarRate = _SolarRate;
        SolarPriceIfZero = _SolarPriceIfZero;
        IfCrystalPowerZero = _IfCrystalPowerZero;
        DaysReturnSolar = _DaysReturnSolar;
    }

    function setPricePolygon(uint256 _NeighboursRange, uint256 _MinPricePolygon, uint256 _CoefPrice) external onlyOwner {
        require(_NeighboursRange != 0 && _MinPricePolygon != 0 && _CoefPrice != 0, "not0");
        NeighboursRange = _NeighboursRange;
        MinPricePolygon = _MinPricePolygon;
        CoefPrice = _CoefPrice;
    }
    function setStakingMintPercent(uint256 _StakingMintPercent) external onlyOwner {
        require(_StakingMintPercent != 0, "not0");
        StakingMintPercent = _StakingMintPercent;
        update_limit();
    }
    

    function WithdrawalFromTheContract() external onlyOwner {
        payable(address(msg.sender)).transfer(address(this).balance);
    }

    /**
     * @notice Check if an address is a contract
     */
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

    /**
     * @notice Allows the owner to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @dev Callable by owner
     */
    function recoverFungibleTokens(IERC20Meta _token) external onlyOwner {
        uint256 amountToRecover = _token.balanceOf(address(this));
        require(amountToRecover != 0, "No token to recover");
        _token.safeTransfer(address(msg.sender), amountToRecover);
        emit TokenRecovery(address(_token), amountToRecover);
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
    //
    modifier onlyMars() {
        require(msg.sender == address(MarsObject) || msg.sender == address(MarsAirDrop), "Not Mars");
        _;
    }
    ///
    IMO public MarsObject;
    function setAddressMarsObject(IMO _MarsObject) external onlyOwner {
        MarsObject = _MarsObject;
    }
    modifier onlyMarsObject() {
        require(msg.sender == address(MarsObject), "Not MarsObject");
        _;
    }
    ///
    IMD public MarsData;
    function setAddressMarsData(IMD _MarsData) external onlyOwner {
        MarsData = _MarsData;
    }
    modifier onlyMarsData() {
        require(msg.sender == address(MarsData), "Not MarsData");
        _;
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
    IMR public MarsReferral;
    function setAddressMarsReferral(IMR _MarsReferral) external onlyOwner {
        MarsReferral = _MarsReferral;
    }
    modifier onlyMarsReferral() {
        require(msg.sender == address(MarsReferral), "Not MarsReferral");
        _;
    }
    ///
    address public MarsBot;
    function setAddressMarsBot(address _MarsBot) external onlyOwner {
        MarsBot = _MarsBot;
    }
    modifier onlyMarsBot() {
        require(msg.sender == MarsBot, "Not MarsBot");
        _;
    }
    ///

}