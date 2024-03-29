// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/JBGovernanceNFT.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JBGovernanceNFTTest is Test {
    JBGovernanceNFT public jbGovernanceNFT;
    ERC20 public stakeToken;

    address public user = address(0x420); 

    function setUp() public {
        vm.startPrank(user);

        stakeToken = new mockERC20();
        jbGovernanceNFT = new JBGovernanceNFT(
            stakeToken
        );

        vm.stopPrank();
    }

    function testMint_single_success(uint200 _amount, address _beneficiary) public {
        JBGovernanceNFTMint[] memory _mints = new JBGovernanceNFTMint[](1);
        // Make sure we have enough balance
        vm.assume(_amount < stakeToken.totalSupply() && _amount != 0);
        // The receiver has to implement 'ERC721Receiver' if its a contract
        vm.assume(_beneficiary.code.length == 0 && _beneficiary != address(0));

        // Give enough token allowance to be able to mint
        vm.startPrank(user);
        stakeToken.increaseAllowance(address(jbGovernanceNFT), _amount);
        // Perform the mint
        _mints[0] = JBGovernanceNFTMint({
            stakeAmount: _amount,
            beneficiary: _beneficiary
        });
        jbGovernanceNFT.mint(_mints);

        assertEq(
            jbGovernanceNFT.stakingTokenBalance(1),
            _amount
        );

        vm.stopPrank();
    }

    function testMint_notEnoughAllowance_reverts(uint200 _amount, uint200 _allowanceTooLittle, address _beneficiary) public {
        JBGovernanceNFTMint[] memory _mints = new JBGovernanceNFTMint[](1);

        // Make sure enough balance exists
        vm.assume(_amount < stakeToken.totalSupply() && _amount != 0);
        vm.assume(_allowanceTooLittle != 0);

        // If allowance too little is more than amount we set no allowance,
        // otherwise we set it as the delta between the two
        // this way we test with no allowance and with too little allowance
        uint200 _allowance;
        if (_allowanceTooLittle <= _amount) 
            _allowance = _amount - _allowanceTooLittle;

        // Give enough token allowance to be able to mint
        vm.startPrank(user);
        stakeToken.increaseAllowance(address(jbGovernanceNFT), _allowance);

        // Perform the mint
        _mints[0] = JBGovernanceNFTMint({
            stakeAmount: _amount,
            beneficiary: _beneficiary
        });

        // This should revert as we have too little balance
        vm.expectRevert();
        jbGovernanceNFT.mint(_mints);

        vm.stopPrank();
    }

    function testMint_multiple_success(uint200[] calldata _amounts, address _beneficiary) public {
        uint256 _sumStaked;
        JBGovernanceNFTMint[] memory _mints = new JBGovernanceNFTMint[](_amounts.length);

        // Can't mint to the 0 address
        // The receiver has to implement 'ERC721Receiver' if its a contract
        vm.assume(_beneficiary.code.length == 0 && _beneficiary != address(0));

        for(uint256 _i; _i < _amounts.length; _i++){
            uint200 _amount = _amounts[_i];
            vm.assume(_amount != 0);
            unchecked{
                // If we overflow the combined amount will be less than the original
                vm.assume(_sumStaked + _amount >= _sumStaked);
                _sumStaked = _sumStaked + _amount;
            }

            _mints[_i] = JBGovernanceNFTMint({
                stakeAmount: _amount,
                beneficiary: _beneficiary
            });
        }
        // Make sure we have enough balance
        vm.assume(_sumStaked < stakeToken.totalSupply());

        vm.prank(user);
        stakeToken.increaseAllowance(address(jbGovernanceNFT), _sumStaked);

        vm.prank(user);
        jbGovernanceNFT.mint(_mints);

        for(uint256 _i = 1; _i <= _amounts.length; _i++){
        assertEq(
            jbGovernanceNFT.stakingTokenBalance(_i),
            _amounts[_i - 1]
        );
        }
    }

    function testBurn_single_success(uint200 _amount, address _beneficiary) public {
        JBGovernanceNFTMint[] memory _mints = new JBGovernanceNFTMint[](1);
        JBGovernanceNFTBurn[] memory _burns = new JBGovernanceNFTBurn[](1);
        // Make sure we have enough balance
        vm.assume(_amount < stakeToken.totalSupply() && _amount != 0);
        // The receiver has to implement 'ERC721Receiver' if its a contract
        vm.assume(_beneficiary.code.length == 0 && _beneficiary != address(0));
        // Give enough token allowance to be able to mint
        vm.startPrank(user);
        stakeToken.increaseAllowance(address(jbGovernanceNFT), _amount);
        // Perform the mint
        _mints[0] = JBGovernanceNFTMint({
            stakeAmount: _amount,
            beneficiary: _beneficiary
        });

        jbGovernanceNFT.mint(_mints);
        vm.stopPrank();
        
        // burn the nft and get stake amount back
        _burns[0] = JBGovernanceNFTBurn({
            tokenId: 1,
            beneficiary: _beneficiary
        });

        vm.startPrank(_beneficiary);

        jbGovernanceNFT.burn(_burns);

        assertEq(
            jbGovernanceNFT.stakingTokenBalance(1),
            0
        );

        assertEq(
            stakeToken.balanceOf(address(jbGovernanceNFT)),
            0
        );

        vm.stopPrank();
    }

    function testBurn_multiple_success(uint200[] calldata _amounts, address _beneficiary) public {
        uint256 _sumStaked;
        JBGovernanceNFTMint[] memory _mints = new JBGovernanceNFTMint[](_amounts.length);
        JBGovernanceNFTBurn[] memory _burns = new JBGovernanceNFTBurn[](_amounts.length);

        // The receiver has to implement 'ERC721Receiver' if its a contract
        vm.assume(_beneficiary.code.length == 0 && _beneficiary != address(0));

        for(uint256 _i; _i < _amounts.length; _i++){
            uint200 _amount = _amounts[_i];
            vm.assume(_amount != 0);
            unchecked{
                // If we overflow the combined amount will be less than the original
                vm.assume(_sumStaked + _amount >= _sumStaked);
                _sumStaked = _sumStaked + _amount;
            }

            _mints[_i] = JBGovernanceNFTMint({
                stakeAmount: _amount,
                beneficiary: _beneficiary
            });
        }
        // Make sure we have enough balance
        vm.assume(_sumStaked < stakeToken.totalSupply());

        vm.prank(user);
        stakeToken.increaseAllowance(address(jbGovernanceNFT), _sumStaked);

        vm.prank(user);
        jbGovernanceNFT.mint(_mints);

        for(uint256 _i; _i < _amounts.length; _i++){
            _burns[_i] = JBGovernanceNFTBurn({
                tokenId: _i + 1,
                beneficiary: _beneficiary
            });
        }
        // burn the nft's
        vm.startPrank(_beneficiary);

        jbGovernanceNFT.burn(_burns);

        for(uint256 _i = 1; _i <= _amounts.length; _i++){
        assertEq(
            jbGovernanceNFT.stakingTokenBalance(_i),
            0
        );
        }

        assertEq(
            stakeToken.balanceOf(address(jbGovernanceNFT)),
            0
        );
        vm.stopPrank();
    }
}


contract mockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MCK") {
        _mint(msg.sender, 100_000 * (10 ** decimals()) );
    }
}