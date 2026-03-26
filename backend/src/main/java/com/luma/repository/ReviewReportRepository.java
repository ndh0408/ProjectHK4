package com.luma.repository;

import com.luma.entity.Review;
import com.luma.entity.ReviewReport;
import com.luma.entity.User;
import com.luma.entity.enums.ReportStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ReviewReportRepository extends JpaRepository<ReviewReport, UUID> {

    boolean existsByReporterAndReview(User reporter, Review review);

    Page<ReviewReport> findByStatus(ReportStatus status, Pageable pageable);

    @Query("SELECT rr FROM ReviewReport rr " +
           "JOIN rr.review r " +
           "JOIN r.event e " +
           "WHERE e.organiser = :organiser " +
           "ORDER BY rr.createdAt DESC")
    Page<ReviewReport> findByOrganiser(@Param("organiser") User organiser, Pageable pageable);

    @Query("SELECT rr FROM ReviewReport rr " +
           "JOIN rr.review r " +
           "JOIN r.event e " +
           "WHERE e.organiser = :organiser AND rr.status = :status " +
           "ORDER BY rr.createdAt DESC")
    Page<ReviewReport> findByOrganiserAndStatus(
            @Param("organiser") User organiser,
            @Param("status") ReportStatus status,
            Pageable pageable);

    @Query("SELECT COUNT(rr) FROM ReviewReport rr " +
           "JOIN rr.review r " +
           "JOIN r.event e " +
           "WHERE e.organiser = :organiser AND rr.status = :status")
    long countByOrganiserAndStatus(@Param("organiser") User organiser, @Param("status") ReportStatus status);

    List<ReviewReport> findByReview(Review review);
}
