pragma solidity ^0.4.24;

import "./Voting.sol";
import "./UserRepository.sol";

contract VotingSystem {
    mapping(address => address[]) votings;
    mapping(address => address[]) userRepositories;
    
    function createVoting(string _text, uint64[] _text_fields, uint64[7] _params, uint64[2] _time, address _user_repo)
        public
        returns(address)
    {
        Voting v = new Voting(_text, _text_fields, _params, _time, _user_repo);
        votings[tx.origin].push(v);
        return v;
    }

    function getVotings() public view returns(address[]) {
        return votings[tx.origin];
    }

    function createUserRepository() public returns(address) {
        UserRepository u = new UserRepository();
        userRepositories[tx.origin].push(u);
        return u;
    }

    function getUserRepositories() public view returns(address[]) {
        return userRepositories[tx.origin];
    }
}
