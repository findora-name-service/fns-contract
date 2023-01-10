// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
import './interface/IFNSRegistry.sol';
import './interface/INameRegistrar.sol';
import './libraries/LibString.sol';
import './libraries/TransferHelper.sol';

contract NameRegistrar is INameRegistrar, ERC721Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using SafeMathUpgradeable for uint256;

    IFNSRegistry public fnsRegistry;
    // The namehash of the TLD this registrar owns (eg, .fra)
    bytes32 public rootNode;
    // root owner
    address public rootOwner;
    // A map of expiry times
    mapping(uint256 => uint256) public expiries;
    // grace period
    uint256 public constant GRACE_PERIOD = 30 days;
    // 
    uint256 public constant ADVANCE_VALID_DAY = 90 days;
    // year
    uint256 public constant ONE_YEAR = 365 days;
    // 
    uint256 public constant REDUCE_RATIO = 5;
    // open petain
    bool public openRetain;
    // first round claim time
    uint256 public firstStartTime;
    uint256 public firstEndTime;
    // second round claim time
    uint256 public secondStartTime;
    uint256 public secondEndTime;
    // preempt time
    uint256 public preemptStartTime;
    uint256 public preemptEndTime;
    // public time
    uint256 public publicStartTime;
    // retain
    mapping(bytes32 => bool) retains;
    // regist fee
    RegistFee[] public registFees;
    // regist fee
    Rebate[] public rebates;
    // regist details
    mapping(uint256 => RegistDetail) public registDetails;
    // recommend statistics
    mapping(address => RecommendStatistic) public recommendStatistics;
    // recommend detail
    mapping(address => RecommendDetail[]) public recommendDetails;
    // regist fee token
    address public feeToken;
    // total fee
    TotalRewardFee public totalRewardFee;
    // manager
    EnumerableSetUpgradeable.AddressSet private managers;
    // whiteList
    EnumerableSetUpgradeable.AddressSet private preemptWhiteLists;
    // address => string
    mapping(address => Beforehand) public firstRegists;
    mapping(address => Beforehand) public secondRegists;
    mapping(uint256 => uint) public advanceLabel;

    bytes4 private constant RECLAIM_ID =
        bytes4(keccak256('reclaim(string)'));

    modifier checkTime(uint deadline, string memory labelStr) {
        require(deadline >= block.timestamp, 'NameRegistrar: EXPIRED');
        if(advanceLabel[_getTokenId(labelStr)] == 1){
            require(block.timestamp > firstEndTime, 'using');
        }
        if(advanceLabel[_getTokenId(labelStr)] == 2){
            require(block.timestamp > secondEndTime, 'using');
        }
        _;
    }

    modifier checkSignature(bytes memory signature, uint deadline, string memory labelStr) {
        bytes32 sigHash = keccak256(abi.encodePacked(deadline, labelStr, msg.sender));
        bytes32 ethSigHash = ECDSAUpgradeable.toEthSignedMessageHash(sigHash);
        require(isManager(ECDSAUpgradeable.recover(ethSigHash, signature)), 'NameRegistrar: invalid signature');
        _;
    }

    modifier retainRegister(string memory labelStr) {
        if(retains[keccak256(abi.encodePacked(labelStr))]){
            require(openRetain, 'not open');
        }
        _;
    }

    function initialize(
        IFNSRegistry fns, 
        bytes32 node, 
        address token, 
        address fnsOwner
    ) public 
        initializer 
    {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __ERC721_init_unchained('Findora Name Service', 'FNS');
        fnsRegistry = fns;
        rootNode = node;
        feeToken = token;
        rootOwner = fnsOwner;
    }

    function getRecommendDetails(address operator) external view returns (RecommendDetail[] memory) {
        return recommendDetails[operator];
    }

    function addManager(address manager) external onlyOwner {
        EnumerableSetUpgradeable.add(managers, manager);
    }

    function delManager(address manager) external onlyOwner {
        EnumerableSetUpgradeable.remove(managers, manager);
    }

    function isManager(address manager) public view returns (bool) {
        return EnumerableSetUpgradeable.contains(managers, manager);
    }

    function addPreemptWhiteLists(address[] memory newPreemptWhiteLists) external onlyOwner {
        for(uint256 i = 0; i < newPreemptWhiteLists.length; i++){
            EnumerableSetUpgradeable.add(preemptWhiteLists, newPreemptWhiteLists[i]);
        }
    }

    function delPreemptWhiteLists(address[] memory newPreemptWhiteLists) external onlyOwner {
        for(uint256 i = 0; i < newPreemptWhiteLists.length; i++){
            EnumerableSetUpgradeable.remove(preemptWhiteLists, newPreemptWhiteLists[i]);
        }
    }

    function isPreemptWhiteList(address user) public view returns (bool) {
        return EnumerableSetUpgradeable.contains(preemptWhiteLists, user);
    }

    function setFirstClaimTime(uint256 startTime, uint256 endTime) external onlyOwner {
        firstStartTime = startTime;
        firstEndTime = endTime;
    }

    function setSecondClaimTime(uint256 startTime, uint256 endTime) external onlyOwner {
        secondStartTime = startTime;
        secondEndTime = endTime;
    }

    function setPreemptTime(uint256 startTime, uint256 endTime) external onlyOwner {
        preemptStartTime = startTime;
        preemptEndTime = endTime;
    }

    function setPublicTime(uint256 startTime) external onlyOwner {
        publicStartTime = startTime;
    }

    function setRegistFees(RegistFee[] memory newRegistFees) external onlyOwner {
        delete registFees;
        for(uint256 i = 0; i < newRegistFees.length; i++){
            registFees.push(
                RegistFee({
                    charNum: newRegistFees[i].charNum,
                    feeAmount: newRegistFees[i].feeAmount
                })
            );
        }
    }

    function setRebates(Rebate[] memory newRebates) external onlyOwner {
        delete rebates;
        for(uint256 i = 0; i < newRebates.length; i++){
            rebates.push(
                Rebate({
                    number: newRebates[i].number,
                    rates: newRebates[i].rates
                })
            );
        }
    }

    function setOpenRetain(bool open) external onlyOwner {
        openRetain = open;
    }

    function addRetains(bytes32[] memory newRetains) external onlyOwner {
        for(uint256 i = 0; i < newRetains.length; i++){
            retains[newRetains[i]] = true;
        }
    }

    function delRetains(bytes32[] memory oldRetains) external onlyOwner {
        for(uint256 i = 0; i < oldRetains.length; i++){
            if(retains[oldRetains[i]]){
                delete retains[oldRetains[i]];
            }
        }
    }

    function retainsExists(bytes32 label) public view returns(bool, bool) {
        return (retains[label], openRetain);
    }

    function nameExpires(uint256 tokenId) external view returns (uint256) {
        return expiries[tokenId];
    }

    function _getTokenId(string memory labelStr) internal pure returns(uint256) {
        return uint256(keccak256(abi.encodePacked(labelStr)));
    }

    function _getNode(uint256 tokenId) internal view returns(bytes32) {
        return keccak256(abi.encodePacked(rootNode, bytes32(tokenId)));
    }

    function _getNode(string memory labelStr) internal view returns(bytes32) {
        bytes32 label = keccak256(abi.encodePacked(labelStr));
        return keccak256(abi.encodePacked(rootNode, label));
    }

    function beforehandRegister(
        address user,
        string memory labelStr,
        uint round
    ) external {
        require(isManager(msg.sender), 'NameRegistrar: Caller is not the manager');
        if(round == 1){
            firstRegists[user] = Beforehand({
                user: user,
                labelStr: labelStr,
                isClaimed: false
            });
        }
        if(round == 2){
            secondRegists[user] = Beforehand({
                user: user,
                labelStr: labelStr,
                isClaimed: false
            });
        }
        advanceLabel[_getTokenId(labelStr)] = round;
    }

    function firstClaim() external {
        require(block.timestamp >= firstStartTime && block.timestamp <= firstEndTime, 'not in time');
        string memory labelStr = firstRegists[msg.sender].labelStr;
        require(bytes(labelStr).length != 0, 'un exist');
        require(!firstRegists[msg.sender].isClaimed, 'is claimed');
        require(advanceLabel[_getTokenId(labelStr)] == 1, 'not this round');
        require(!fnsRegistry.recordExists(_getNode(labelStr)), 'using');
        uint256 expirie = firstStartTime + ADVANCE_VALID_DAY;
        _register(labelStr, expirie, 0, msg.sender);
        firstRegists[msg.sender].isClaimed = true;
    }

    function secondClaim() external {
        require(block.timestamp >= secondStartTime && block.timestamp <= secondEndTime, 'not in time');
        string memory labelStr = secondRegists[msg.sender].labelStr;
        require(bytes(labelStr).length != 0, 'un exist');
        require(!secondRegists[msg.sender].isClaimed, 'is claimed');
        require(advanceLabel[_getTokenId(labelStr)] == 2, 'not this round');
        require(!fnsRegistry.recordExists(_getNode(labelStr)), 'using');
        uint256 expirie = secondStartTime + ADVANCE_VALID_DAY;
        _register(labelStr, expirie, 0, msg.sender);
        secondRegists[msg.sender].isClaimed = true;
    }

    function preemptRegister(
        string memory labelStr,
        uint256 duration,
        bytes32 recommendNode,
        bytes memory signature,
        uint deadline
    ) external
        checkTime(deadline, labelStr)
        checkSignature(signature, deadline, labelStr)
        retainRegister(labelStr)
    {
        require(block.timestamp >= preemptStartTime && block.timestamp <= preemptEndTime, 'not in time');
        require(
            firstRegists[msg.sender].user != address(0) 
            || secondRegists[msg.sender].user != address(0)
            || isPreemptWhiteList(msg.sender)
            , 'no permission');
        uint256 tokenId = _getTokenId(labelStr);
        require(!fnsRegistry.recordExists(_getNode(tokenId)), 'using');
        _feeAndRebate(labelStr, tokenId, duration, recommendNode);
        uint256 expirie = block.timestamp + duration.mul(ONE_YEAR);
        _register(labelStr, expirie, GRACE_PERIOD, msg.sender);
    }

    function register(
        string memory labelStr,
        uint256 duration,
        bytes32 recommendNode,
        bytes memory signature,
        uint deadline
    ) external 
        checkTime(deadline, labelStr)
        checkSignature(signature, deadline, labelStr)
        retainRegister(labelStr) 
    {
        require(block.timestamp >= publicStartTime, 'not in time');
        uint256 tokenId = _getTokenId(labelStr);
        require(!fnsRegistry.recordExists(_getNode(tokenId)), 'using');
        _feeAndRebate(labelStr, tokenId, duration, recommendNode);
        uint256 expirie = block.timestamp + duration.mul(ONE_YEAR);
        _register(labelStr, expirie, GRACE_PERIOD, msg.sender);
    }

    function _register(
        string memory labelStr,
        uint256 expirie,
        uint256 gracePeriod,
        address owner
    ) internal {
        uint256 tokenId = _getTokenId(labelStr);
        expiries[tokenId] = block.timestamp + expirie;
        if (_exists(tokenId)) {
            // Name was previously owned, and expired
            _burn(tokenId);
        }
        _mint(owner, tokenId);
        bytes32 subnode = fnsRegistry.setSubnodeOwner(rootNode, labelStr, bytes32(tokenId), owner);
        fnsRegistry.setExpirie(subnode, expiries[tokenId].add(gracePeriod));
        fnsRegistry.setDefaultText(subnode, getDefaultText());
        emit NameRegistered(tokenId, owner, expiries[tokenId]);
    }

    function renew(
        string memory labelStr, 
        uint256 duration
    ) external {
        uint256 tokenId = _getTokenId(labelStr);
        require(_exists(tokenId), 'unusing');
        require(expiries[tokenId] + GRACE_PERIOD >= block.timestamp, 'period exceeded');
        RegistFee memory registFee = getRegistFee(labelStr);
        uint256 yearFee = registFee.feeAmount.mul(duration);
        TransferHelper.safeTransferFrom(feeToken, msg.sender, address(this), yearFee);
        expiries[tokenId] += duration.mul(ONE_YEAR);
        registDetails[tokenId].expiries = expiries[tokenId];
        fnsRegistry.setExpirie(
            _getNode(tokenId), 
            expiries[tokenId].add(GRACE_PERIOD)
        );
        emit NameRenewed(tokenId, expiries[tokenId]);
    }

    function _feeAndRebate(
        string memory labelStr,
        uint256 tokenId,
        uint256 duration,
        bytes32 recommendNode
    ) internal {
        // regists
        registDetails[tokenId] = RegistDetail({
            labelStr: labelStr,
            tokenId: tokenId,
            registAddr: msg.sender,
            registTime: block.timestamp,
            expiries: block.timestamp + duration.mul(ONE_YEAR)
        });
        //regist fee
        RegistFee memory registFee = getRegistFee(labelStr);
        uint256 yearFee = registFee.feeAmount.mul(duration);
        // Recommend
        address recommender = fnsRegistry.currentOwner(recommendNode);
        if(recommender != rootOwner && recommender != address(0)){
            Rebate memory rebate  = _getRebate(recommendStatistics[recommender].number.add(1));
            uint256 reduceFee = yearFee.mul(REDUCE_RATIO).div(100);
            uint256 chargeFee = yearFee.sub(reduceFee);
            uint256 rewardFee = chargeFee.mul(rebate.rates).div(100);
            TransferHelper.safeTransferFrom(feeToken, msg.sender, address(this), chargeFee);
            recommendStatistics[recommender].number = recommendStatistics[recommender].number.add(1);
            recommendStatistics[recommender].rewards = recommendStatistics[recommender].rewards.add(rewardFee);
            recommendDetails[recommender].push(
                RecommendDetail({
                    labelStr: labelStr,
                    tokenId: tokenId,
                    registAddr: msg.sender,
                    registTime: block.timestamp,
                    registFee: chargeFee,
                    reward: rewardFee
                })
            );
            totalRewardFee.rewards += rewardFee;
        } else {
            TransferHelper.safeTransferFrom(feeToken, msg.sender, address(this), yearFee);
        }
    }

    function getRegistFee(string memory labelStr) public view returns (RegistFee memory registFee) {
        for(uint256 i = registFees.length.sub(1); i.add(1) != 0; i--){
            if(bytes(labelStr).length >= registFees[i].charNum){
                registFee = registFees[i];
                break;
            }
        }
        return registFee;
    }

    function _getRebate(uint256 number) internal view returns (Rebate memory rebate) {
        for(uint256 i = 0; i < rebates.length; i++){
            if(number < rebates[i].number){
                rebate = rebates[i];
                break;
            }
        }
        return rebate;
    }

    function mergeTransfer(string memory labelStr, address to) external {
        uint256 tokenId = _getTokenId(labelStr);
        require(_isApprovedOrOwner(msg.sender, tokenId), 'not owner');
        super.safeTransferFrom(msg.sender, to, tokenId);
        fnsRegistry.setOwner(_getNode(tokenId), to);
        fnsRegistry.delAllSubnodeOwner(_getNode(tokenId));
    }

    function reclaim(string memory labelStr) public {
        uint256 tokenId = _getTokenId(labelStr);
        require(_isApprovedOrOwner(msg.sender, tokenId), 'not owner');
        fnsRegistry.setOwner(_getNode(tokenId), msg.sender);
        fnsRegistry.delAllSubnodeOwner(_getNode(tokenId));
    }

    function claimRewards() external nonReentrant {
        uint256 balance = TransferHelper.safeBalanceOf(feeToken, address(this));
        uint256 rewards = recommendStatistics[msg.sender].rewards;
        uint256 extracted = recommendStatistics[msg.sender].extracted;
        uint256 actual = rewards.sub(extracted);
        if(actual > 0 && actual <= balance){
            TransferHelper.safeTransfer(feeToken, msg.sender, actual);
            recommendStatistics[msg.sender].extracted += actual;
            totalRewardFee.extracted += actual;
            emit Claim(msg.sender, actual);
        }
    }

    function withrawFee(address to, uint256 amount) external onlyOwner {
        uint256 balance = TransferHelper.safeBalanceOf(feeToken, address(this));
        uint256 real = balance.sub(totalRewardFee.rewards.sub(totalRewardFee.extracted));
        if(amount > 0 && amount <= real){
            TransferHelper.safeTransfer(feeToken, to, amount);
            emit Withraw(to, amount, msg.sender);
        }
    }

    function ownerOf(uint256 tokenId)
        public
        view
        override(IERC721Upgradeable, ERC721Upgradeable)
        returns (address)
    {
        require(expiries[tokenId] > block.timestamp, 'unused');
        return super.ownerOf(tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            getApproved(tokenId) == spender ||
            isApprovedForAll(owner, spender));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == RECLAIM_ID || 
            super.supportsInterface(interfaceId);
    }

    function getDefaultText() internal view returns(string memory) {
        string memory front = '{"ETH":"';
        string memory rear = '"}';
        return LibString.concat(
            LibString.concat(front, StringsUpgradeable.toHexString(uint256(uint160(msg.sender)))), 
            rear
        );
    }
}