# marsverse-smart-contracts

1. Deploy the MarsToken.sol contract

2. Deploy the MarsObject.sol contarct
  1)_SIZEX - map size by x (5120)
  2)_SIZEY - map size by y (2560)

3. Deploy the MarsData.sol contarct

4. Deploy the MarsControl.sol contarct
  1)_MarsTokenAddress - the address of the contract MarsToken.sol
  2)_MarsObject - address of the contract MarsObject.sol
  3)_MarsData - address of the contract MarsData.sol
  4)_AdminAddress - the address of the admin where the money will be sent, if the addresses of the MarsPool and MarsChef pools are not installed
  5)_marsbot - the address of the bot that is given the opportunity to perform the auto_take() function
  6)_solarrate - 100000000000 Wei (0.0000001 ETH) the rate for 1 solar
  7)_SolarPriceIfZero - 1000 solar, if the price of the item is not determined, then this is the amount in solar
  8)_NeighboursRange - 100 distance between neighbors (if there are plots in this range, they are neighbors)
  9)_MINPRICEPOLYGON - 100000000000000 (0.0001 eth) minimum price per polygon with 0 neighbors
  10)_COEFPRICE - 10 .the price coefficient, where 1 is an increase in price by 100% for each guest, 10 is an increase in price by 10% for each guest,, 100 is an increase in price by 1% for each guest

5. Deploy the MarsReferral.sol contarct
  1) the address of the contract is MarsControl.sol
  2) the address of the MarsData.sol contract
  3) the address of the contract is MarsAirdrop.sol or 0x00000000000000000000000000000000000000000000 if not

6. Deploy the MarsAirDrop.sol contarct
  1) the address of the contract is MarsControl.sol
  2) the address of the MarsData.sol contract
  3) the address of the MarsObject.sol contract

7. Call MarsToken.setAddressMarsControl(Address of MarsControl.sol)
8. Call MarsObject.setAddressMarsControl(Address of MarsControl.sol)
9. Call marsdata.setAddressMarsControl(Address of MarsControl.sol)
10. Call MarsData.setAddressMarsReferral(Address of MarsReferral.sol)
11. Call MarsControl.setAddressMarsReferral(Address of MarsReferral.sol)
12. Call MarsControl.setAddressMarsAirDrop(Address of MarsAirDrop.sol)
13. Call MarsControl.startContract()
