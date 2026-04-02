package com.luma.service;

import com.luma.dto.response.analytics.*;
import com.luma.entity.enums.EventStatus;
import com.luma.entity.enums.RegistrationStatus;
import com.luma.entity.enums.UserRole;
import com.luma.repository.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class AnalyticsService {

    private final UserRepository userRepository;
    private final EventRepository eventRepository;
    private final RegistrationRepository registrationRepository;
    private final PaymentRepository paymentRepository;
    private final CategoryRepository categoryRepository;
    private final CityRepository cityRepository;

    public DashboardAnalyticsResponse getDashboardAnalytics() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startOfMonth = now.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0);
        LocalDateTime startOfLastMonth = startOfMonth.minusMonths(1);

        long totalUsers = userRepository.count();
        long usersThisMonth = userRepository.countByCreatedAtAfter(startOfMonth);
        long usersLastMonth = userRepository.countByCreatedAtBetween(startOfLastMonth, startOfMonth);
        double userGrowth = calculateGrowthPercent(usersLastMonth, usersThisMonth);

        long totalEvents = eventRepository.count();
        long eventsThisMonth = eventRepository.countByCreatedAtAfter(startOfMonth);
        long eventsLastMonth = eventRepository.countByCreatedAtBetween(startOfLastMonth, startOfMonth);
        double eventGrowth = calculateGrowthPercent(eventsLastMonth, eventsThisMonth);

        long totalRegistrations = registrationRepository.count();
        long registrationsThisMonth = registrationRepository.countByCreatedAtAfter(startOfMonth);
        long registrationsLastMonth = registrationRepository.countByCreatedAtBetween(startOfLastMonth, startOfMonth);
        double registrationGrowth = calculateGrowthPercent(registrationsLastMonth, registrationsThisMonth);

        BigDecimal totalRevenue = paymentRepository.calculateTotalRevenue();
        BigDecimal revenueThisMonth = paymentRepository.calculateRevenueBetween(startOfMonth, now);
        BigDecimal revenueLastMonth = paymentRepository.calculateRevenueBetween(startOfLastMonth, startOfMonth);
        double revenueGrowth = calculateGrowthPercent(
                revenueLastMonth.doubleValue(),
                revenueThisMonth.doubleValue()
        );

        return DashboardAnalyticsResponse.builder()
                .totalUsers(totalUsers)
                .newUsersThisMonth(usersThisMonth)
                .userGrowthPercent(userGrowth)
                .totalEvents(totalEvents)
                .newEventsThisMonth(eventsThisMonth)
                .eventGrowthPercent(eventGrowth)
                .totalRegistrations(totalRegistrations)
                .newRegistrationsThisMonth(registrationsThisMonth)
                .registrationGrowthPercent(registrationGrowth)
                .totalRevenue(totalRevenue)
                .revenueThisMonth(revenueThisMonth)
                .revenueGrowthPercent(revenueGrowth)
                .userGrowthChart(getUserGrowthChart(6))
                .eventGrowthChart(getEventGrowthChart(6))
                .registrationGrowthChart(getRegistrationGrowthChart(6))
                .revenueChart(getRevenueChart(6))
                .eventsByCategory(getEventsByCategory())
                .eventsByCity(getEventsByCity(10))
                .eventsByStatus(getEventsByStatus())
                .topOrganisers(getTopOrganisers(5))
                .topEvents(getTopEvents(5))
                .build();
    }

    public List<TimeSeriesData> getUserGrowthChart(int months) {
        List<TimeSeriesData> data = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth yearMonth = YearMonth.from(today.minusMonths(i));
            LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
            LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

            long count = userRepository.countByCreatedAtBetween(start, end);
            data.add(TimeSeriesData.builder()
                    .date(yearMonth.atDay(1))
                    .count(count)
                    .build());
        }

        return data;
    }

    public List<TimeSeriesData> getEventGrowthChart(int months) {
        List<TimeSeriesData> data = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth yearMonth = YearMonth.from(today.minusMonths(i));
            LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
            LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

            long count = eventRepository.countByCreatedAtBetween(start, end);
            data.add(TimeSeriesData.builder()
                    .date(yearMonth.atDay(1))
                    .count(count)
                    .build());
        }

        return data;
    }

    public List<TimeSeriesData> getRegistrationGrowthChart(int months) {
        List<TimeSeriesData> data = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth yearMonth = YearMonth.from(today.minusMonths(i));
            LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
            LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

            long count = registrationRepository.countByCreatedAtBetween(start, end);
            data.add(TimeSeriesData.builder()
                    .date(yearMonth.atDay(1))
                    .count(count)
                    .build());
        }

        return data;
    }

    public List<TimeSeriesData> getRevenueChart(int months) {
        List<TimeSeriesData> data = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth yearMonth = YearMonth.from(today.minusMonths(i));
            LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
            LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

            BigDecimal amount = paymentRepository.calculateRevenueBetween(start, end);
            data.add(TimeSeriesData.builder()
                    .date(yearMonth.atDay(1))
                    .amount(amount != null ? amount : BigDecimal.ZERO)
                    .build());
        }

        return data;
    }

    public List<CategoryDistribution> getEventsByCategory() {
        List<Object[]> results = eventRepository.countEventsByCategory();
        long totalEvents = eventRepository.count();

        return results.stream()
                .map(row -> CategoryDistribution.builder()
                        .categoryId((Integer) row[0])
                        .categoryName((String) row[1])
                        .eventCount((Long) row[2])
                        .percentage(totalEvents > 0 ?
                                ((Long) row[2] * 100.0 / totalEvents) : 0)
                        .build())
                .collect(Collectors.toList());
    }

    public List<CityDistribution> getEventsByCity(int limit) {
        List<Object[]> results = eventRepository.countEventsByCity();
        long totalEvents = eventRepository.count();

        return results.stream()
                .limit(limit)
                .map(row -> CityDistribution.builder()
                        .cityId((Integer) row[0])
                        .cityName((String) row[1])
                        .country((String) row[2])
                        .eventCount((Long) row[3])
                        .percentage(totalEvents > 0 ?
                                ((Long) row[3] * 100.0 / totalEvents) : 0)
                        .build())
                .collect(Collectors.toList());
    }

    public List<StatusDistribution> getEventsByStatus() {
        List<StatusDistribution> data = new ArrayList<>();
        long totalEvents = eventRepository.count();

        for (EventStatus status : EventStatus.values()) {
            long count = eventRepository.countByStatus(status);
            data.add(StatusDistribution.builder()
                    .status(status.name())
                    .count(count)
                    .percentage(totalEvents > 0 ? (count * 100.0 / totalEvents) : 0)
                    .build());
        }

        return data;
    }

    public List<TopOrganiser> getTopOrganisers(int limit) {
        List<Object[]> results = eventRepository.findTopOrganisersByRegistrations(limit);

        return results.stream()
                .map(row -> TopOrganiser.builder()
                        .id((UUID) row[0])
                        .name((String) row[1])
                        .email((String) row[2])
                        .avatarUrl((String) row[3])
                        .totalEvents((Long) row[4])
                        .totalRegistrations((Long) row[5])
                        .totalRevenue(row[6] != null ? (BigDecimal) row[6] : BigDecimal.ZERO)
                        .build())
                .collect(Collectors.toList());
    }

    public List<TopEvent> getTopEvents(int limit) {
        List<Object[]> results = eventRepository.findTopEventsByRegistrations(limit);

        return results.stream()
                .map(row -> {
                    Integer capacity = (Integer) row[6];
                    Long regCount = (Long) row[4];
                    double fillRate = capacity != null && capacity > 0 ?
                            (regCount * 100.0 / capacity) : 0;

                    return TopEvent.builder()
                            .id((UUID) row[0])
                            .title((String) row[1])
                            .organiserName((String) row[2])
                            .imageUrl((String) row[3])
                            .registrationCount(regCount)
                            .revenue(row[5] != null ? (BigDecimal) row[5] : BigDecimal.ZERO)
                            .fillRate(Math.min(fillRate, 100))
                            .build();
                })
                .collect(Collectors.toList());
    }

    public OrganiserAnalyticsResponse getOrganiserAnalytics(UUID organiserId) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startOfMonth = now.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0);

        long totalEvents = eventRepository.countByOrganiserId(organiserId);
        long activeEvents = eventRepository.countByOrganiserIdAndStatus(organiserId, EventStatus.PUBLISHED);
        long totalRegistrations = registrationRepository.countByEventOrganiserId(organiserId);
        BigDecimal totalRevenue = paymentRepository.calculateRevenueByOrganiser(organiserId);

        return OrganiserAnalyticsResponse.builder()
                .totalEvents(totalEvents)
                .activeEvents(activeEvents)
                .totalRegistrations(totalRegistrations)
                .totalRevenue(totalRevenue != null ? totalRevenue : BigDecimal.ZERO)
                .registrationGrowthChart(getOrganiserRegistrationChart(organiserId, 6))
                .revenueChart(getOrganiserRevenueChart(organiserId, 6))
                .build();
    }

    private List<TimeSeriesData> getOrganiserRegistrationChart(UUID organiserId, int months) {
        List<TimeSeriesData> data = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth yearMonth = YearMonth.from(today.minusMonths(i));
            LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
            LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

            long count = registrationRepository.countByEventOrganiserIdAndCreatedAtBetween(organiserId, start, end);
            data.add(TimeSeriesData.builder()
                    .date(yearMonth.atDay(1))
                    .count(count)
                    .build());
        }

        return data;
    }

    private List<TimeSeriesData> getOrganiserRevenueChart(UUID organiserId, int months) {
        List<TimeSeriesData> data = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (int i = months - 1; i >= 0; i--) {
            YearMonth yearMonth = YearMonth.from(today.minusMonths(i));
            LocalDateTime start = yearMonth.atDay(1).atStartOfDay();
            LocalDateTime end = yearMonth.atEndOfMonth().atTime(23, 59, 59);

            BigDecimal amount = paymentRepository.calculateRevenueByOrganiserBetween(organiserId, start, end);
            data.add(TimeSeriesData.builder()
                    .date(yearMonth.atDay(1))
                    .amount(amount != null ? amount : BigDecimal.ZERO)
                    .build());
        }

        return data;
    }

    private double calculateGrowthPercent(long lastPeriod, long thisPeriod) {
        if (lastPeriod == 0) {
            return thisPeriod > 0 ? 100.0 : 0.0;
        }
        return ((double) (thisPeriod - lastPeriod) / lastPeriod) * 100;
    }

    private double calculateGrowthPercent(double lastPeriod, double thisPeriod) {
        if (lastPeriod == 0) {
            return thisPeriod > 0 ? 100.0 : 0.0;
        }
        return ((thisPeriod - lastPeriod) / lastPeriod) * 100;
    }
}
