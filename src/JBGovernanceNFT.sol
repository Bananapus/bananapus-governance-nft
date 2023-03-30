// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {JBGovernanceNFTMint} from "./structs/JBGovernanceNFTMint.sol";
import {JBGovernanceNFTBurn} from "./structs/JBGovernanceNFTBurn.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712, ERC721, ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";


/**
 * @title JB Governance NFT
 * @dev Used for granting voting rights and staking functionality to the holder. 
   @dev
    Adheres to -
    ERC721Votes: For enabling the voting and delegation mechanism.
 */
contract JBGovernanceNFT is ERC721Votes {
    using SafeERC20 for IERC20;

    event Mint(uint256 _tokenId, address _stakedAt);
    event Burn(uint256 _tokenId);

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
    uint256 numberOfTokens;

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
     * @return _tokenId The token IDs of the newly minted NFTs.
    */
    function mint(JBGovernanceNFTMint[] calldata _mints) external returns (uint256[] memory) {
        address _sender = _msgSender();
        uint256[] memory _tokenIds = new uint256[](_mints.length);
        for (uint256 _i; _i < _mints.length;) {
            // Should never be 0
            if (_mints[_i].stakeAmount == 0) 
                revert INVALID_STAKE_AMOUNT(_i, _mints[_i].stakeAmount);
            // Transfer the stake amount from the user
            stakedToken.safeTransferFrom(_sender, address(this), _mints[_i].stakeAmount);
            // Increase the amount of tokens that exist
            // and use the new number as the id
            unchecked {
                _tokenIds[_i] = ++numberOfTokens;
            }
            stakingTokenBalance[_tokenIds[_i]] = _mints[_i].stakeAmount;
            // Living on the edge, using safemint because we can
            _safeMint(_mints[_i].beneficiary, _tokenIds[_i]);
            emit Mint(_tokenIds[_i], _sender);
            // Get the tokenId to use and increment it for the next usage
            unchecked {
                ++_i;
            }
        }

        return _tokenIds;
    }

    /**
     * @dev Burn the nft and unstake tokens.
     * @param _burns An array of struct containing the token id and beneficiary to be sent the staked tokens to.
    */
    function burn(JBGovernanceNFTBurn[] calldata _burns) external {
        address _sender = _msgSender();
        for (uint256 _i; _i < _burns.length;) {
            uint256 _tokenId = _burns[_i].tokenId;
            // Make sure only approved addresses can do this
            if (!_isApprovedOrOwner(_sender, _tokenId)) 
                revert NO_PERMISSION(_tokenId);  
            // Immedialty burn to prevernt reentrency
            _burn(_tokenId);
            // Release the stake
            // We can transfer before deleting from storage since the NFT is burned
            // Any attempt at reentrence will revert since the storage delete is non-critical
            stakedToken.transfer(_burns[_i].beneficiary, stakingTokenBalance[_tokenId]);
            // Delete the position
            delete stakingTokenBalance[_tokenId];
            emit Burn(_tokenId);
            unchecked {
                ++_i;
            }
        } 
    }
}
