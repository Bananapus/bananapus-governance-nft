// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IJBGovernanceNFT {

    function stakedToken() external view returns(IERC20);

    function stakingTokenBalance(uint256 _tokenId) external view returns(uint256);

}