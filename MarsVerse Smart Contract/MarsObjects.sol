// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IMC {
    function update_power_Ex(address account) external;
    function is_active(address _address) external view returns (bool);
    function NeighboursRange() view external returns (uint256);
}

contract MarsObjects is ERC1155, Ownable, ReentrancyGuard {

    constructor(uint256 _sizeX, uint256 _sizeY) ERC1155("http://localhost/api/{id}.json") {
        MapSize = [_sizeX, _sizeY];

        add_img(100, 200, 300);
        add_img(500, 500, 300);
        add_img(800, 800, 300);

        add_field(0, 640, 320, 2863);
        add_field(0, 160, 640, 2863);
        add_field(0, 640, 1120, 2863);
        add_field(1, 640, 800, 2863);
        add_field(1, 1280, 1120, 2863);
        add_field(1, 1920, 800, 2863);
        add_field(2, 1280, 800, 2863);
        add_field(2, 1920, 320, 2863);
        add_field(2, 2400, 1120, 2863);

        add_property_type(1000, 0, 0, 100);          //0
        add_property_type(0, 1000, 0, 100);          //1
        add_property_type(0, 0, 1000, 100);          //2
        add_property_type(1000, 1000, 0, 100);       //3
        add_property_type(0, 1000, 1000, 100);       //4
        add_property_type(1000, 0, 1000, 100);       //5
        add_property_type(1000, 1000, 1000, 100);    //6

        add_property_type(2000, 0, 0, 95);          //0
        add_property_type(0, 2000, 0, 95);          //1
        add_property_type(0, 0, 2000, 95);          //2
        add_property_type(2000, 2000, 0, 95);       //3
        add_property_type(0, 2000, 2000, 95);       //4
        add_property_type(2000, 0, 2000, 95);       //5
        add_property_type(2000, 2000, 2000, 95);    //6

        add_property_type(4000, 0, 0, 90);          //0
        add_property_type(0, 4000, 0, 90);          //1
        add_property_type(0, 0, 4000, 90);          //2
        add_property_type(4000, 4000, 0, 90);       //3
        add_property_type(0, 4000, 4000, 90);       //4
        add_property_type(4000, 0, 4000, 90);       //5
        add_property_type(4000, 4000, 4000, 90);    //6
    }

    /////////////////////// Events /////////////////////

    event NewImg(uint img_id, uint x, uint y, uint range);
    event NewField(uint field_id, uint field_type_id, uint x, uint y, uint range);
    event NewPolygon(uint polygon_id, address indexed account, uint x, uint y);
    event PropertyEvent(uint256 indexed polygon_id, uint256 property_type_id);

    /////////////////////// Struct /////////////////////

    uint256[2] public MapSize;

    struct Imginfo {
        uint256 x;
        uint256 y;
        uint256 range;
    }
    uint256 public img_count;
    mapping (uint => Imginfo) public Img;

    struct Fieldinfo {
        uint256 field_type_id; 
        uint256 x;
        uint256 y;
        uint256 range;
    }
    uint256 public field_count;
    mapping (uint => Fieldinfo) public Field;

    struct PropertyTypeinfo {
        uint256[3] power;
        uint256 discount;
        bool exist;
    }
    uint256 public propertytype_count;
    mapping (uint => PropertyTypeinfo) PropertyType;

    struct Polygoninfo {
        address account;
        uint256 x; 
        uint256 y;
        uint256 propertys_count;
    }
    mapping (uint => Polygoninfo) public Polygon;
    uint256 public polygon_count = 10;

    mapping (address => uint256) public ownerPolygonCount;


    struct Propertyinfo {
        uint256 polygon_id;
        uint256 property_type_id;
        uint256 level;
    }
    uint256 public property_count;
    mapping (uint => Propertyinfo) public Property;

    /////////////////////// Functions /////////////////////

    function edit_MapSize(uint256 _sizeX, uint256 _sizeY) public onlyOwner notContract nonReentrant {
        MapSize = [_sizeX, _sizeY];
    }
    function get_MapSize() external view returns (uint[2] memory) {
        return MapSize;
    }

    function add_img(uint _x, uint _y, uint _range) public onlyOwner notContract nonReentrant {
        Img[img_count].x = _x;
        Img[img_count].y = _y;
        Img[img_count].range = _range;
        emit NewImg(img_count, _x, _y, _range);
        img_count += 1;
    }

    function add_field(uint _field_type_id, uint _x, uint _y, uint _range) public onlyOwner notContract nonReentrant {
        require (_field_type_id == 0 || _field_type_id == 1 || _field_type_id == 2);
        Field[field_count].field_type_id = _field_type_id;
        Field[field_count].x = _x;
        Field[field_count].y = _y;
        Field[field_count].range = _range;
        emit NewField(field_count, _field_type_id, _x, _y, _range);
        field_count += 1;
    }

    function add_property_type(uint _power0, uint _power1, uint _power2, uint _discount) public onlyOwner notContract nonReentrant {
        PropertyType[propertytype_count].power = [_power0, _power1, _power2];
        PropertyType[propertytype_count].discount = _discount;
        PropertyType[propertytype_count].exist = true;
        propertytype_count += 1;
    }

    function add_polygon(address _account, uint256 _x, uint256 _y) private {
        require (_x <= MapSize[0] && _y <= MapSize[1]);
        Polygon[polygon_count].account = _account;
        Polygon[polygon_count].x = _x;
        Polygon[polygon_count].y = _y;
        ownerPolygonCount[_account] += 1;
        _mint(_account, polygon_count, 1, "");
        emit NewPolygon(polygon_count, _account, _x, _y);
        polygon_count += 1;
    }
    function add_polygon_Ex(address _address, uint256 _x, uint256 _y) external onlyMarsControl {
        add_polygon(address(_address), _x, _y);
    }

    function add_property(uint _property_type_id, uint _polygon_id, uint _level) private {
        require (PropertyType[_property_type_id].exist == true);
        require (Polygon[_polygon_id].account != address(0));
        for (uint i = 0; i < property_count; i++) { 
            if (Property[i].polygon_id == _polygon_id) { 
                require (Property[i].property_type_id != _property_type_id, "This type already exists");
            }
        }
        Property[property_count].property_type_id = _property_type_id;
        Property[property_count].level = _level;
        Property[property_count].polygon_id = _polygon_id;
        property_count += 1;
        Polygon[_polygon_id].propertys_count += 1;
        emit PropertyEvent(_polygon_id, _property_type_id);
    }
    function add_property_Ex(uint _property_type_id, uint _polygon_id, uint _level) external onlyMarsControl {
        add_property(_property_type_id, _polygon_id, _level);
    }

    function property_level_up_Ex(address _account, uint256 _property_id) external onlyMarsControl {
        require (Property[_property_id].polygon_id != 0); 
        require (Polygon[Property[_property_id].polygon_id].account == _account, "This polygon does not belong to you");
        Property[_property_id].level += 1;
        emit PropertyEvent(Property[_property_id].polygon_id, Property[_property_id].property_type_id);
    }
    /////////// Views ///////////

    function get_PropertyType(uint256 _property_type_id) external view returns (PropertyTypeinfo memory) {
        return PropertyType[_property_type_id];
    }

    function get_account_power_Ex(address _address) external view returns (uint[] memory) {
        uint[] memory _sum_powers = new uint[](3);
        for (uint i = 0; i < polygon_count; i++) {
            if (Polygon[i].account == _address) {
                uint[] memory _distance_power = get_distance_power(i);
                _sum_powers[0] += _distance_power[0];
                _sum_powers[1] += _distance_power[1];
                _sum_powers[2] += _distance_power[2];
            }
        }
        return _sum_powers;
    }

    function get_distance_power(uint _polygon_id) public view returns (uint[] memory) {
        require (Polygon[_polygon_id].account != address(0));

        uint[] memory _powers = new uint[](3);
        uint[] memory _result_powers = new uint[](3);
        uint[] memory _count_fields = new uint[](3);

        for (uint i = 0; i < property_count; i++) { 
            if (Property[i].polygon_id == _polygon_id) { 
                _powers[0] += PropertyType[Property[i].property_type_id].power[0]*Property[i].level; 
                _powers[1] += PropertyType[Property[i].property_type_id].power[1]*Property[i].level; 
                _powers[2] += PropertyType[Property[i].property_type_id].power[2]*Property[i].level; 
            }
        }
        for (uint i = 0; i < field_count; i++) { 
            _count_fields[Field[i].field_type_id] += 1;
        }
        for (uint i = 0; i < field_count; i++) {
            uint distance = get_distance(int(Polygon[_polygon_id].x), int(Polygon[_polygon_id].y), int(Field[i].x), int(Field[i].y));
            if (Field[i].range > distance) { 
                uint perc_production = 100-(distance*100/Field[i].range);
                perc_production = perc_production/_count_fields[Field[i].field_type_id];
                _result_powers[Field[i].field_type_id] += _powers[Field[i].field_type_id] * perc_production / 100;
            }
        }
        return _result_powers;
    }


    /////////////////////// Halpers /////////////////////
    function update_power(address _address) private {
        MarsControl.update_power_Ex(_address);
    }


    function get_distance(int _x1, int _y1, int _x2, int _y2) public pure returns (uint256) {
        uint x = uint(abs(_x1-_x2));
        uint y = uint(abs(_y1-_y2));
        return sqrt2((x*x) + (y*y));
    }
    function sqrt2(uint x) private pure returns(uint) {
        uint z = (x + 1 ) / 2;
        uint y = x;
        while(z < y) { 
            y = z;
            z = ( x / z + z ) / 2;
        } 
        return y; 
    }
    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }


    
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);

        if (Polygon[id].account != address(0)) {
            Polygon[id].account = to;
            ownerPolygonCount[from] -= 1;
            ownerPolygonCount[to] += 1;
            update_power(from);
            update_power(to);
        }
    }


    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
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

    ////////
    IMC public MarsControl;
    function setAddressMarsControl(IMC _MarsControl) external onlyOwner {
        MarsControl = _MarsControl;
    }
    modifier onlyMarsControl() {
        require(msg.sender == address(MarsControl), "Not MarsControl");
        _;
    }
}