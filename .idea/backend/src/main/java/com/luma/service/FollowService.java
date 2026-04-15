package com.luma.service;

import com.luma.dto.response.OrganiserResponse;
import com.luma.dto.response.PageResponse;
import com.luma.dto.response.UserResponse;
import com.luma.entity.Follow;
import com.luma.entity.OrganiserProfile;
import com.luma.entity.User;
import com.luma.exception.BadRequestException;
import com.luma.repository.FollowRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@RequiredArgsConstructor
public class FollowService {

    private final FollowRepository followRepository;
    private final OrganiserService organiserService;

    @Transactional
    public void followOrganiser(User follower, UUID organiserId) {
        OrganiserProfile organiser = organiserService.getEntityByUserId(organiserId);

        if (follower.getId().equals(organiserId)) {
            throw new BadRequestException("You cannot follow yourself");
        }

        if (followRepository.existsByFollowerAndOrganiser(follower, organiser)) {
            throw new BadRequestException("You are already following this organiser");
        }

        Follow follow = Follow.builder()
                .follower(follower)
                .organiser(organiser)
                .build();

        followRepository.save(follow);
        organiserService.incrementFollowers(organiser);
    }

    @Transactional
    public void unfollowOrganiser(User follower, UUID organiserId) {
        OrganiserProfile organiser = organiserService.getEntityByUserId(organiserId);

        if (!followRepository.existsByFollowerAndOrganiser(follower, organiser)) {
            throw new BadRequestException("You are not following this organiser");
        }

        followRepository.deleteByFollowerAndOrganiser(follower, organiser);
        organiserService.decrementFollowers(organiser);
    }

    @Transactional(readOnly = true)
    public boolean isFollowing(User follower, UUID organiserId) {
        OrganiserProfile organiser = organiserService.getEntityByUserId(organiserId);
        return followRepository.existsByFollowerAndOrganiser(follower, organiser);
    }

    @Transactional(readOnly = true)
    public PageResponse<OrganiserResponse> getFollowing(User follower, Pageable pageable) {
        Page<Follow> follows = followRepository.findByFollower(follower, pageable);
        return PageResponse.from(follows, f -> OrganiserResponse.fromEntity(f.getOrganiser()));
    }

    @Transactional(readOnly = true)
    public long getFollowerCount(UUID organiserId) {
        OrganiserProfile organiser = organiserService.getEntityByUserId(organiserId);
        return followRepository.countByOrganiser(organiser);
    }

    @Transactional(readOnly = true)
    public PageResponse<UserResponse> getFollowers(User organiser, Pageable pageable) {
        Page<Follow> follows = followRepository.findByOrganiserUser(organiser, pageable);
        return PageResponse.from(follows, f -> UserResponse.fromEntity(f.getFollower()));
    }
}
