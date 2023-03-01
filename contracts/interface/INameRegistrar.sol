// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import '@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol';

interface INameRegistrar is IERC721Upgradeable {

    struct Beforehand {
        address user;
        string labelStr;
        bool isClaimed;
    }

    struct RegistFee {
        uint256 charNum;
        uint256 feeAmount;
    }

    struct Rebate {
        uint256 number;
        uint256 rates;
    }

    struct TotalRewardFee {
        uint256 rewards;
        uint256 extracted;
    }

    struct RegistDetail {
        string labelStr;
        uint256 tokenId;
        address registAddr;
        uint256 registTime;
        uint256 expiries;
    }

    struct RecommendStatistic {
        uint256 number;
        uint256 rewards;
        uint256 extracted;
    }

    struct RecommendDetail {
        string labelStr;
        uint256 tokenId;
        address registAddr;
        uint256 registTime;
        uint256 registFee;
        uint256 reward;
    }

    event NameRegistered(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 expires
    );

    event NameRenewed(uint256 indexed tokenId, uint256 expires);

    event Claim(address indexed operator, uint256 amount);

    event Withraw(address indexed to, uint256 amount, address operator);
}