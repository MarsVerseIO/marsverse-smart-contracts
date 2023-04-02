// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts@4.4.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.4.2/access/Ownable.sol";

contract MarsToken is ERC20, Ownable {

    constructor() ERC20("MarsVerse Token", "LAVA") {
        LastTimeHalving = block.timestamp;
        DailyDistribution = 2000 * 10 ** decimals();
    }

    uint256 public LastTimeHalving;
    uint256 public DailyDistribution;
    uint256 public HalvingCount;
    uint256 public DaysBeforeHalving = 240;

    event NewMint(address account, uint amount, uint reason);

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
        emit NewMint(_to, _amount, 2);        // reason 0 - steaking, 1 - user, 2 - admin 
    }

    function postpone_halving() public onlyOwner {
        LastTimeHalving = block.timestamp;
    }

    function edit_DaysBeforeHalving(uint256 _days) public onlyOwner {
        DaysBeforeHalving = _days;
    }
    
    function mint_operator(address _to, uint256 _amount, uint256 _reason) external onlyMarsControl {
        _mint(_to, _amount);
        emit NewMint(_to, _amount, _reason);         // reason 0 - steaking, 1 - user, 2 - admin 
    }

    function get_DailyDistribution() external returns(uint256) {
        if (LastTimeHalving+(86400*DaysBeforeHalving) < block.timestamp) {
            LastTimeHalving = block.timestamp;
            DailyDistribution = DailyDistribution/2;
            HalvingCount++;
        }
        return DailyDistribution;
    }

    address public MarsControl;
    function setAddressMarsControl(address _MarsControl) external onlyOwner {
        require(_MarsControl != address(0), "not0");
        MarsControl = _MarsControl;
    }
    modifier onlyMarsControl() {
        require(msg.sender == MarsControl, "Not MarsControl");
        _;
    }
}