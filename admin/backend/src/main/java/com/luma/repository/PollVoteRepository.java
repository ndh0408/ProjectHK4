package com.luma.repository;

import com.luma.entity.Poll;
import com.luma.entity.PollVote;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface PollVoteRepository extends JpaRepository<PollVote, UUID> {

    boolean existsByPollAndUser(Poll poll, User user);

    List<PollVote> findByPollAndUser(Poll poll, User user);

    List<PollVote> findByPoll(Poll poll);

    long countByPoll(Poll poll);
}
