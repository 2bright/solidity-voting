pragma solidity ^0.4.24;

import "./UserRepository.sol";

contract Voting {
    address owner;
    
    // title and description of voting and options.
    // format as "title" + "description" + "option 0 title" + "option 0 description" + ...
    // field range is stored in text_fields
    string text;
    
    // end index of each field in text
    // title: [0, text_fields[0]]
    // description: [text_fields[0], text_fields[1]]
    // option 0 title: [text_fields[1], text_fields[2]]
    // option 0 description: [text_fields[2], text_fields[3]]
    uint64[] text_fields;
    
    // how many options could one voter select.
    uint64 select_min;
    uint64 select_max;
    
    // If isAnonymous is true, do not record the options that voter selected.
    uint64 isAnonymous;
    
    // If isPublic is true, any user could vote without being added to user_repo.
    uint64 isPublic;
    
    // If multiWinner is false but has multiple winners, then result is no winner.
    uint64 multiWinner;
    
    // if a winner has votes count less than thresholdWinnerVotes, voting has no winner.
    // thresholdWinnerVotes is min percent of winner votes to total votes.
    uint64 thresholdWinnerVotes;
    
    // if total votes count is less than thresholdTotalVotes, voting has no winner.
    // if isPublic is true, thresholdTotalVotes is min count of votes.
    // if isPublic is false, thresholdTotalVotes is min percent of total votes to total users.
    uint64 thresholdTotalVotes;
    
    // allow voting after to_start_time
    // 0 means allow voting after call startVoting
    uint64 to_start_time;
    
    // deny voting after to_end_time
    // 0 means deny voting after call endVoting
    uint64 to_end_time;
    
    // the time deploy this contract
    uint64 create_time;
    
    UserRepository user_repo;

    // map from voter address to vote index
    mapping(address => uint) votes_index;
    
    // all votes
    // index 0 store no vote
    Vote[] votes;
    
    VoteResult result;
    
    struct Vote {
        address voter;
        
        // selected option indexes. If isAnonymous is true, ignore this field.
        uint64[] optionIDs;
        
        // vote time
        uint64 add_time;
    }
    
    struct VoteResult {
        // option indexes which has max votes count
        // if no winner, winners.length is zero.
        uint64[] winners;
        
        // votes count for each option
        uint64[] options;
        
        // total votes count
        uint64 votes;
        
        // if isPublic is true, voters_count is equal to votes_count.
        // is isPublic is false, voters_count is user_repo count.
        uint64 voters;
        
        uint64 start_time;
        
        uint64 end_time;
        
        VotingStatus status;
    }
    
    enum VotingStatus {TO_START, VOTING, ENDED, SETTLED}
    
    // _text: "title" + "description" + "option 0 title" + "option 0 description" + ...
    // _text_fields: [end index of "title", end index of "description", end index of "option 0 title", ...]
    // _params: select_min, select_max, isAnonymous, isPublic, multiWinner, thresholdWinnerVotes, thresholdTotalVotes
    // _time: to_start_time, to_end_time
    constructor(string _text, uint64[] _text_fields, uint64[7] _params, uint64[2] _time, address _user_repo) public {
        uint option_count = _text_fields.length / 2 - 1;
        
        require(
            bytes(_text).length == _text_fields[_text_fields.length - 1] && 
            _text_fields.length >= 6 && 
            _text_fields.length % 2 == 0 && 
            _params[0] >= 1 && 
            _params[1] <= option_count && 
            (_time[0] == 0 || _time[0] >= now) && 
            (_time[1] == 0 || _time[1] >= now)
        );
        
        owner = tx.origin;
        
        text = _text;
        text_fields = _text_fields;
        
        result.options = new uint64[](option_count);
        
        select_min = _params[0];
        select_max = _params[1];
        isAnonymous = _params[2];
        isPublic = _params[3];
        multiWinner = _params[4];
        thresholdWinnerVotes = uint8(_params[5]);
        thresholdTotalVotes = _params[6];
        
        to_start_time = _time[0];
        to_end_time = _time[1];
        create_time = uint64(now);
        
        if (isPublic == 0) {
            if (0 == _user_repo) {
                user_repo = new UserRepository();
            } else {
                user_repo = UserRepository(_user_repo);
            }
        }
        
        votes.push(Vote(0, new uint64[](0), 0));
    }

    function getVotingInfo()
        public
        view 
        returns(address _owner, string _text, uint64[] _text_fields, uint64[7] _params, uint64[3] _time, address _user_repo)
    {
        _owner = owner;
        _text = text;
        _text_fields = text_fields;
        _params = [select_min, select_max, isAnonymous, isPublic, multiWinner, thresholdWinnerVotes, thresholdTotalVotes];
        _time = [to_start_time, to_end_time, create_time];
        _user_repo = user_repo;
    }

    // _extra: _votes, _voters, _start_time, _end_time, _status
    function getVotingResult()
        public
        view 
        returns(uint64[] _winners, uint64[] _options, uint64[5] _extra)
    {
        VoteResult memory r = result;
        
        _winners = r.winners;
        _options = r.options;
        
        _extra[0] = r.votes;
        
        if (r.status == VotingStatus.SETTLED) {
            _extra[1] = r.voters;
        } else if (isEnded()) {
            _extra[1] = user_repo.countBefore(r.end_time > 0 ? r.end_time : to_end_time);
        } else {
            _extra[1] = user_repo.count();
        }
        
        // start_time
        _extra[2] = 0;
        // end_time
        _extra[3] = 0;
        // status
        _extra[4] = uint8(VotingStatus.TO_START);

        if (r.start_time > 0) {
            _extra[2] = r.start_time;
            _extra[4] = uint8(VotingStatus.VOTING);
        } else if (to_start_time > 0 && now >= to_start_time) {
            _extra[2] = to_start_time;
            _extra[4] = uint8(VotingStatus.VOTING);
        }
        
        if (r.end_time > 0) {
            _extra[3] = r.end_time;
            _extra[4] = uint8(VotingStatus.ENDED);
        } else if (to_end_time > 0 && now >= to_end_time) {
            _extra[3] = to_end_time;
            _extra[4] = uint8(VotingStatus.ENDED);
        }
        
        if (r.status == VotingStatus.SETTLED) {
            _extra[4] = uint8(VotingStatus.SETTLED);
        }
    }
    
    function vote(uint64[] _optionIDs) external returns(bool) {
        address voter = msg.sender;

        require(
            !isEnded() && 
            isStarted() && 
            (isPublic > 0 || user_repo.hasUser(voter)) &&
            0 == votes_index[voter] &&
            _optionIDs.length >= select_min &&
            _optionIDs.length <= select_max
        );
        
        uint64 option_count = uint64(result.options.length);
        
        bool[] memory _options = new bool[](option_count);
        
        uint64 i = 0;
        uint64 n = 0;
        
        for (i = 0; i < _optionIDs.length; i++) {
            require(_optionIDs[i] < option_count);
            
            if (!_options[_optionIDs[i]]) {
                n++;
                _options[_optionIDs[i]] = true;
            }
        }
        
        Vote memory v = Vote({voter:voter, optionIDs:new uint64[](isAnonymous > 0 ? 0 : n), add_time:uint64(now)});
        
        uint j = 0;
        for (i = 0; i < option_count; i++) {
            if (_options[i]) {
                result.options[i]++;
                if (isAnonymous == 0) {
                    v.optionIDs[j] = i;
                    j++;
                }
            }
        }
        
        votes.push(v);
        
        result.votes = uint64(votes.length) - 1;
        
        return true;
    }
    
    function startVoting() external returns(bool) {
        require(tx.origin == owner && to_start_time == 0);
        
        if (result.start_time == 0) {
            result.start_time = uint64(now);
            result.status = VotingStatus.VOTING;
        }
        
        return true;
    }
    
    function endVoting() external returns(bool) {
        require(tx.origin == owner && to_end_time == 0 && isStarted());
        
        if (result.end_time == 0) {
            result.end_time = uint64(now);
            result.status = VotingStatus.ENDED;
        }
        
        return true;
    }

    function settleVoting() external returns(bool) {
        require(isEnded());
        
        result.votes = uint64(votes.length) - 1;
        result.voters = user_repo.countBefore(result.end_time > 0 ? result.end_time : to_end_time);
        
        uint64 max_votes_count = 0;
        uint64 winner_count = 0;
        
        uint len = result.options.length;
        uint64 option_count = 0;
        uint64 i = 0;
        
        for (i = 0; i < len; i++) {
            option_count = result.options[i];
            if (max_votes_count < option_count) {
                max_votes_count = option_count;
                winner_count = 1;
            } else if (max_votes_count == option_count) {
                winner_count++;
            }
        }
        
        if ((winner_count == 1 || (winner_count > 1 && multiWinner > 0))
            && (isPublic == 0 || result.votes >= thresholdTotalVotes)
            && (isPublic > 0 || result.votes >= (result.voters * thresholdTotalVotes / 100 + (result.voters * thresholdTotalVotes % 100 > 0 ? 1 : 0)))
            && max_votes_count >= (result.votes * thresholdWinnerVotes / 100 + (result.votes * thresholdWinnerVotes % 100 > 0 ? 1 : 0))
        ) {
            for (i = 0; i < len; i++) {
                if (max_votes_count == result.options[i]) {
                    result.winners.push(i);
                }
            }
        }
        
        result.status = VotingStatus.SETTLED;
        
        return true;
    }
    
    function isStarted() internal view returns(bool) {
        return (result.start_time > 0 || (to_start_time > 0 && now >= to_start_time));
    }
    
    function isEnded() internal view returns(bool) {
        return (result.end_time > 0 || (to_end_time > 0 && now >= to_end_time));
    }
}
