// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {JBGovernanceNFTMint} from "./structs/JBGovernanceNFTMint.sol";
import {JBGovernanceNFTBurn} from "./structs/JBGovernanceNFTBurn.sol";

import "@openzeppelin/contracts/utils/Checkpoints.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712, ERC721, ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";


/**
 * @title JB Governance NFT
 * @dev Used for granting voting rights and staking functionality to the holder. 
   @dev
    Adheres to -
    ERC721Votes: For enabling the voting and delegation mechanism.
 */
contract JBGovernanceNFT is ERC721Votes, ReentrancyGuard {
    using Checkpoints for Checkpoints.History;
    using SafeERC20 for IERC20;

    event NFT_Minted_and_Staked(uint256 _tokenId, address _stakedAt);
    event NFT_Burnt_and_Unstaked(uint256 _tokenId);

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error NO_PERMISSION(uint256 _tokenId);
    error INVALID_STAKE_AMOUNT(uint256 _i, uint256 _amount);

    /**
     * @dev The ERC20 token that is used for staking.
     */
    IERC20 immutable stakedToken;

    /**
     * @dev A mapping of staked token balances per id, we can track the owner by ownerOf so don't need a struct as key
     */
    mapping(uint256 => uint256) public stakingTokenBalance;

    /**
     * @dev The next available token ID to be minted.
     */
    uint256 nextokenId = 1;

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /**
     * @param _stakedToken The ERC20 token to use for staking.
     */
    constructor(IERC20 _stakedToken) ERC721("", "") EIP712("", "") {
        stakedToken = _stakedToken;
    }

    /**
     * @dev Mint a new NFT and stake tokens.
     * @param _mints An array of struct containing the beneficiary and stake amount for each NFT to be minted.
     * @return _tokenId The token ID of the newly minted NFT.
    */
    function mint_and_stake(JBGovernanceNFTMint[] calldata _mints) external nonReentrant returns (uint256 _tokenId) {
        address _sender = _msgSender();
        for (uint256 _i; _i < _mints.length;) {
            // Should never be 0
            if (_mints[_i].stakeAmount == 0) {
                revert INVALID_STAKE_AMOUNT(_i, _mints[_i].stakeAmount);
            }

            stakingTokenBalance[nextokenId] += _mints[_i].stakeAmount;

            // Living on the edge, using safemint because we can
            _safeMint(_mints[_i].beneficiary, nextokenId);
    
             _tokenId = nextokenId;

            emit NFT_Minted_and_Staked(nextokenId, _sender);

            // Transfer the stake amount from the user
            stakedToken.safeTransferFrom(_sender, address(this), _mints[_i].stakeAmount);

            // Get the tokenId to use and increment it for the next usage
            unchecked {
                ++_i;
                nextokenId += 1;
            }
        }
    }

    /**
     * @dev Burn the nft and unstake tokens.
     * @param _burns An array of struct containing the token id and beneficiary to be sent the staked tokens too.
    */
    function burn_and_unstake(JBGovernanceNFTBurn[] calldata _burns) external  nonReentrant {
        for (uint256 _i; _i < _burns.length;) {
            uint256 _tokenId = _burns[_i].tokenId;
            address _owner = _ownerOf(_tokenId);
            address _beneficiary = _burns[_i].beneficiary;

            // Make sure only the owner can do this
            if (_owner != msg.sender) 
                revert NO_PERMISSION(_tokenId);  
            
            uint256 _stakeAmount = stakingTokenBalance[_tokenId];
            delete stakingTokenBalance[_tokenId];

            emit NFT_Burnt_and_Unstaked(_tokenId);

            _burn(_tokenId);

            stakedToken.transfer(_beneficiary, _stakeAmount);

            unchecked {
                ++_i;
            }
        } 
    }
}
