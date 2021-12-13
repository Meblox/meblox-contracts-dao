// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MebloxDAO is Ownable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /// @param memberAddress Addresse of the member
    /// @param permissions 1:have permission, 0:no permission
    struct Member {
        address memberAddress;
        int permissions;
    }

    /// @param tokenAddress Addresse of the fund
    /// @param fundName Name of the fund
    struct FundPool {
        address tokenAddress;
        string fundName;
    }

    /// @param memberAddress The addresse of member
    /// @param agree, 0: Don't vote, 1: yes, 2: no
    /// @param comments Comments during the vote
    /// @param voteTime The voting time
    struct Votes {
        address memberAddress;
        int agree;
        string comments;
        uint256 voteTime;
    }

    /// @param executeTime resolution execution time
    /// @param executeStatus 0: non-execution, 1: executed
    /// @param totalVotesCount The total number of votes cast for this resolution
    /// @param agreeCount The total number of votes agreed
    /// @param resolutionTitle Resolution title
    /// @param resolutionContent Resolution content
    /// @param voteValidTime Voting deadline (block)
    /// @param executeValidTime Execution deadline (block)
    /// @param executeHash Execution TX
    /// @param ceateTime Resolution creation time
    struct ResolutionContent {
        uint256 resolutionIndex;
        uint256 resolutionId;
        uint256 executeTime;
        uint256 executeStatus;
        uint256 totalVotesCount;
        uint256 agreeCount;
        string resolutionTitle;
        string resolutionContent;
        uint256 voteValidTime;
        uint256 executeValidTime;
        string executeHash;
        uint256 ceateTime;
    }

    /// @param resolutionTitle Resolution title
    /// @param executeStatus 0: non-execution, 1: executed
    /// @param totalVotesCount The total number of votes cast for this resolution
    /// @param agreeCount The total number of votes agreed
    /// @param voteValidTime Voting deadline (block)
    /// @param executeValidTime Execution deadline (block)
    /// @param ceateTime Resolution creation time
    struct Resolution {
        uint256 resolutionId;
        string resolutionTitle;
        uint256 executeStatus;
        uint256 totalVotesCount;
        uint256 agreeCount;
        uint256 voteValidTime;
        uint256 executeValidTime;
        uint256 ceateTime;
    }

    Member[] public memberList;
    FundPool[] public fundPoolList;
    Resolution[] public resolutionList;

    mapping (uint256 => ResolutionContent) resolutionContentList;
    mapping (uint256 => Votes[]) resolutionVotesList;

    event LogAddMember(address);
    event LogSetMemberPermissions(address, int);
    event LogAddFundPool(address, string);
    event LogSetFundPool(uint256, string);
    event LogAddResolution(uint256 resolutionId, uint256 totalVotesCount, Votes[] votes);
    event LogMemberVotes(uint256 resolutionId, address msgSender, uint256 agreeCount);
    event LogExecuteResolution(uint256 resolutionId, uint256 agreeCount);

    /// Member
    /// @param _memberAddress Addresse of the new member
    /// [notice] Upon success, the member will have permissions
    function addMember(address _memberAddress) public onlyOwner {
        bool _isNewMember = true;
        for (uint256 _index = 0; _index < memberList.length; _index++) {
            if (memberList[_index].memberAddress == _memberAddress) {
                _isNewMember = false;
            }
        }
        require(_isNewMember, "The address is already a member");

        memberList.push(
            Member({
                memberAddress: _memberAddress,
                permissions: 1
            })
        );
        emit LogAddMember(_memberAddress);
    }

    /// @param _memberId Member ID
    /// @param _permissions 1:have permission, 0:no permission
    function setMemberPermissions(uint256 _memberId, int _permissions) public onlyOwner {
        Member storage member = memberList[_memberId];
        member.permissions = _permissions;
        emit LogSetMemberPermissions(member.memberAddress, _permissions);
    }

    function getMemberList() public view returns (Member[] memory) {
        return memberList;
    }

    function getMemberListLength() public view returns (uint256) {
        return memberList.length;
    }

    /// FundPool
    /// @param _tokenAddress Addresse of the fund
    /// @param _fundName Name of the fund
    function addFundPool(address _tokenAddress, string memory _fundName) public onlyOwner {
        fundPoolList.push(
            FundPool({
                tokenAddress: _tokenAddress,
                fundName: _fundName
            })
        );
        emit LogAddFundPool(_tokenAddress, _fundName);
    }

    /// @param _fundPoolId Fund ID
    /// @param _fundName Name of the fund
    function setFundPool(uint256 _fundPoolId, string memory _fundName) public onlyOwner {
        FundPool memory fundPool = fundPoolList[_fundPoolId];
        fundPool.fundName = _fundName;
        emit LogSetFundPool(_fundPoolId, _fundName);
    }

    function getFundPool(uint256 _fundPoolId) public view returns (FundPool memory) {
        return fundPoolList[_fundPoolId];
    }

    function getFundPoolList() public view returns (FundPool[] memory) {
        return fundPoolList;
    }

    function getFundPoolListLength() public view returns (uint256) {
        return fundPoolList.length;
    }

    /// Resolution
    /// @param _resolutionTitle Resolution title
    /// @param _resolutionContent Resolution content
    /// @param _voteValidTime The current block plus this value
    /// @param _executeValidTime The current block plus this value
    function addResolution(string memory _resolutionTitle, string memory _resolutionContent, uint256 _voteValidTime, uint256 _executeValidTime) public onlyOwner {
        uint256 _resolutionId = block.number;
        uint256 _memberListLength = getMemberListLength();
        uint256 _ceateTime = block.timestamp;

        for (uint i = 0; i < _memberListLength; i++) {
            Member memory member = memberList[i];
            if ( member.permissions == 1 ) {
                resolutionVotesList[_resolutionId].push(
                    Votes({
                        memberAddress: member.memberAddress,
                        agree: 0,
                        comments: "",
                        voteTime: 0
                    })
                );
            }
        }

        uint256 _voteValidTimeResult = _resolutionId.add(_voteValidTime);
        uint256 _executeValidTimeResult = _resolutionId.add(_executeValidTime);

        resolutionList.push(
            Resolution({
                resolutionId: _resolutionId,
                resolutionTitle: _resolutionTitle,
                executeStatus: 0,
                totalVotesCount: resolutionVotesList[_resolutionId].length,
                agreeCount: 0,
                ceateTime: _ceateTime,
                voteValidTime: _voteValidTimeResult,
                executeValidTime: _executeValidTimeResult
            })
        );

        resolutionContentList[_resolutionId] = ResolutionContent({
            resolutionIndex: resolutionList.length.sub(1),
            resolutionId: _resolutionId,
            executeTime: 0,
            executeStatus: 0,
            totalVotesCount: resolutionVotesList[_resolutionId].length,
            agreeCount: 0,
            resolutionTitle: _resolutionTitle,
            resolutionContent: _resolutionContent,
            voteValidTime: _voteValidTimeResult,
            executeValidTime: _executeValidTimeResult,
            executeHash: "",
            ceateTime: _ceateTime
        });

        emit LogAddResolution(_resolutionId, resolutionVotesList[_resolutionId].length, resolutionVotesList[_resolutionId]);
    }

    /// @param _resolutionId Resolution id
    /// @param _agree 1: yes, 2: no
    /// @param _comments vote moments
    function memberVotes(uint256 _resolutionId, int _agree, string memory _comments) public returns (address) {
        ResolutionContent storage resolution = resolutionContentList[_resolutionId];
        uint256 _lastBlock = block.number;
        uint256 _timestamp = block.timestamp;

        require(_lastBlock <= resolution.voteValidTime, "[1]Voting time has expired");
        require(_lastBlock <= resolution.executeValidTime, "[2]Voting time has expired");
        require(resolution.executeStatus == 0, "Resolution has been executed");

        bool _resolutionMember = false;
        uint _memberIndex = 0;

        for (uint _index = 0; _index < resolutionVotesList[_resolutionId].length; _index++) {
            if (resolutionVotesList[_resolutionId][_index].memberAddress == msg.sender) {
                _resolutionMember = true;
                _memberIndex = _index;
                break;
            }
        }

        require(_resolutionMember, "You're not a member");
        require(resolutionVotesList[_resolutionId][_memberIndex].agree == 0, "You have already voted");

        resolutionVotesList[_resolutionId][_memberIndex].agree = _agree;
        resolutionVotesList[_resolutionId][_memberIndex].comments = _comments;
        resolutionVotesList[_resolutionId][_memberIndex].voteTime = _timestamp;

        if (_agree == 1) {
            resolution.agreeCount = resolution.agreeCount.add(1);
            resolutionList[resolution.resolutionIndex].agreeCount = resolution.agreeCount;
        }

        emit LogMemberVotes(_resolutionId, msg.sender, resolution.agreeCount);
        return msg.sender;
    }

    function executeResolution(uint256 _resolutionId, string memory _executeHash) public onlyOwner {
        ResolutionContent storage resolution = resolutionContentList[_resolutionId];
        uint256 _lastBlock = block.number;

        require(resolution.executeStatus == 0, "Resolution has been executed.");
        require(resolution.agreeCount >= resolution.totalVotesCount.div(2).add(1), "Insufficient votes.");
        require(resolution.executeValidTime > _lastBlock, "The executable time has exceeded.");

        resolution.executeStatus = 1;
        resolution.executeTime = _lastBlock;
        resolution.executeHash = _executeHash;
        resolutionList[resolution.resolutionIndex].executeStatus = 1;

        emit LogExecuteResolution(_resolutionId, resolution.agreeCount);
    }

    function getResolutionListItem(uint _resolutionIndex) public view returns (Resolution memory) {
        return resolutionList[_resolutionIndex];
    }

    function getResolutionList() public view returns (Resolution[] memory) {
        return resolutionList;
    }

    function getResolutionContent(uint256 _resolutionId) public view returns (ResolutionContent memory) {
        return resolutionContentList[_resolutionId];
    }

    function getResolutionListLength() public view returns (uint256) {
        return resolutionList.length;
    }

    function getResolutionVotes(uint256 _resolutionId) public view returns (Votes[] memory) {
        return resolutionVotesList[_resolutionId];
    }
}
