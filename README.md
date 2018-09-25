# solidity-voting
    This project aims to be a common voting system.

# design
    There are three contract, VotingSystem, Voting and UserRepository.

    contract VotingSystem is for managing Voting and UserRepository.
    contract Voting is for voting logic.
    contract UserRepository is for sharing voters across Voting.

    If Voting is public, anyone could vote without being added to a UserRepository.

# workflow

## public voting
    > publisher invoke VotingSystem.createVoting to get a Voting contract address.
    > anyone invoke Voting.getVotingInfo to get voting info stored when createVoting.
    > publisher invoke Voting.startVoting if to_start_time is not provided when createVoting.
    > voters (anyone) invoke Voting.vote.
    > publisher invoke Voting.endVoting if to_end_time is not provided when createVoting.
    > anyone invoke Voting.settleVoting to calculate the winner after voting end.
    > anyone invoke Voting.getVotingResult to get voting winner.

## permissioned voting
    > publisher invoke VotingSystem.createUserRepository to create a new UserRepository, or use a existing UserRepository.
    > publisher invoke UserRepository.addUsers to add users who has permission to vote.
    > publisher invoke VotingSystem.createVoting to get a Voting contract address, providing a UserRepository address as a parameter.
    > anyone invoke Voting.getVotingInfo to get voting info stored when createVoting.
    > publisher invoke Voting.startVoting if to_start_time is not provided when createVoting.
    > voters (user in the UserRepository) invoke Voting.vote.
    > publisher invoke Voting.endVoting if to_end_time is not provided when createVoting.
    > anyone invoke Voting.settleVoting to calculate the winner after voting end.
    > anyone invoke Voting.getVotingResult to get voting winner.

# usage
    Please refer to solidity source code in ./contracts directory.
