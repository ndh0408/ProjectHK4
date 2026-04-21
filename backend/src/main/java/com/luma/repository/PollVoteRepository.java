package com.luma.repository;

import com.luma.entity.Poll;
import com.luma.entity.PollVote;
import com.luma.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Set;
import java.util.UUID;

@Repository
public interface PollVoteRepository extends JpaRepository<PollVote, UUID> {

    boolean existsByPollAndUser(Poll poll, User user);

    List<PollVote> findByPollAndUser(Poll poll, User user);

    List<PollVote> findByPoll(Poll poll);

    long countByPoll(Poll poll);

    @Query("SELECT DISTINCT v.poll.id FROM PollVote v " +
           "WHERE v.user = :user AND v.poll.id IN :pollIds")
    Set<UUID> findVotedPollIdsByUserAndPollIds(@Param("user") User user,
                                                @Param("pollIds") Collection<UUID> pollIds);

    /// Option IDs this user has voted on for a single poll. Used by the
    /// chat message / poll detail responses so the UI can highlight the
    /// user's own picks after they vote (MULTIPLE_CHOICE can have several).
    @Query("SELECT v.option.id FROM PollVote v " +
           "WHERE v.user = :user AND v.poll.id = :pollId AND v.option IS NOT NULL")
    Set<UUID> findVotedOptionIdsByPollAndUser(@Param("pollId") UUID pollId,
                                               @Param("user") User user);
}
