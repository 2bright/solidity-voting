pragma solidity ^0.4.24;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/VotingSystem.sol";

contract TestVotingSystem {
    function testVotingSystem() public {
        VotingSystem vSys = VotingSystem(DeployedAddresses.VotingSystem());

        string memory _text = "123456";
        uint64[] memory _text_fields = new uint64[](6);

        for (uint64 i = 0; i < 6; i++) {
            _text_fields[i] = i + 1;
        }

        uint64[7] memory _params = [uint64(1), uint64(1), uint64(0), uint64(0), uint64(0), uint64(50), uint64(67)];
        uint64[2] memory _time = [uint64(0), uint64(0)];
        address _user_repo = 0;
        address[] memory user_repos;

        address voting1 = vSys.createVoting(_text, _text_fields, _params, _time, _user_repo);
        Assert.notEqual(0, voting1, "createVoting error");

        _user_repo = vSys.createUserRepository();
        Assert.notEqual(0, _user_repo, "getVotings error");

        address voting2 = vSys.createVoting(_text, _text_fields, _params, _time, _user_repo);
        Assert.notEqual(0, voting2, "createVoting error");

        user_repos = vSys.getUserRepositories();
        Assert.equal(1, user_repos.length, "getVotings error");
        Assert.equal(_user_repo, user_repos[0], "getVotings error");

        address[] memory vs = vSys.getVotings();
        Assert.equal(2, vs.length, "getVotings error");
        Assert.equal(voting1, vs[0], "getVotings error");
        Assert.equal(voting2, vs[1], "getVotings error");
    }
}
