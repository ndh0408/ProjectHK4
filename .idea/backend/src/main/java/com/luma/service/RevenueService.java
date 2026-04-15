package com.luma.service;

import com.luma.dto.response.RevenueStatsResponse;
import com.luma.dto.response.RevenueStatsResponse.*;
import com.luma.entity.EventBoost;
import com.luma.entity.OrganiserSubscription;
import com.luma.entity.enums.BoostPackage;
import com.luma.entity.enums.SubscriptionPlan;
import com.luma.repository.EventBoostRepository;
import com.luma.repository.OrganiserSubscriptionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class RevenueService {

    private final EventBoostRepository boostRepository;
    private final OrganiserSubscriptionRepository subscriptionRepository;

    @Transactional(readOnly = true)
    public RevenueStatsResponse getRevenueStats() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startOfMonth = now.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0);
        LocalDateTime startOfLastMonth = startOfMonth.minusMonths(1);

        BigDecimal totalBoostRevenue = boostRepository.sumAllPaidBoostRevenue();
        BigDecimal monthlyBoostRevenue = boostRepository.sumPaidBoostRevenueAfter(startOfMonth);
        BigDecimal lastMonthBoostRevenue = boostRepository.sumPaidBoostRevenueBetween(startOfLastMonth, startOfMonth);

        List<OrganiserSubscription> allSubscriptions = subscriptionRepository.findAllPaidSubscriptions();
        List<OrganiserSubscription> monthlySubscriptions = subscriptionRepository.findPaidSubscriptionsAfter(startOfMonth);
        List<OrganiserSubscription> lastMonthSubscriptions = subscriptionRepository.findPaidSubscriptionsBetween(startOfLastMonth, startOfMonth);

        BigDecimal totalSubscriptionRevenue = sumSubscriptionRevenue(allSubscriptions);
        BigDecimal monthlySubscriptionRevenue = sumSubscriptionRevenue(monthlySubscriptions);
        BigDecimal lastMonthSubscriptionRevenue = sumSubscriptionRevenue(lastMonthSubscriptions);

        BigDecimal totalRevenue = totalBoostRevenue.add(totalSubscriptionRevenue);
        BigDecimal monthlyRevenue = monthlyBoostRevenue.add(monthlySubscriptionRevenue);
        BigDecimal lastMonthRevenue = lastMonthBoostRevenue.add(lastMonthSubscriptionRevenue);

        Double revenueGrowth = calculateGrowthPercent(lastMonthRevenue, monthlyRevenue);
        Double subscriptionGrowth = calculateGrowthPercent(lastMonthSubscriptionRevenue, monthlySubscriptionRevenue);
        Double boostGrowth = calculateGrowthPercent(lastMonthBoostRevenue, monthlyBoostRevenue);

        int totalSubscriptionCount = subscriptionRepository.countAllPaidSubscriptions();
        int activeSubscriptionCount = subscriptionRepository.countActiveValidSubscriptions(now);
        int totalBoostCount = boostRepository.countAllPaidBoosts();
        int activeBoostCount = boostRepository.countActiveBoostsNow(now);

        Map<String, PlanStats> subscriptionByPlan = calculateSubscriptionByPlan(now);
        Map<String, PackageStats> boostByPackage = calculateBoostByPackage();
        List<MonthlyRevenue> monthlyTrend = calculateMonthlyTrend();

        return RevenueStatsResponse.builder()
                .totalRevenue(totalRevenue)
                .subscriptionRevenue(totalSubscriptionRevenue)
                .boostRevenue(totalBoostRevenue)
                .monthlyRevenue(monthlyRevenue)
                .monthlySubscriptionRevenue(monthlySubscriptionRevenue)
                .monthlyBoostRevenue(monthlyBoostRevenue)
                .lastMonthRevenue(lastMonthRevenue)
                .lastMonthSubscriptionRevenue(lastMonthSubscriptionRevenue)
                .lastMonthBoostRevenue(lastMonthBoostRevenue)
                .revenueGrowthPercent(revenueGrowth)
                .subscriptionGrowthPercent(subscriptionGrowth)
                .boostGrowthPercent(boostGrowth)
                .totalSubscriptions(totalSubscriptionCount)
                .activeSubscriptions(activeSubscriptionCount)
                .totalBoosts(totalBoostCount)
                .activeBoosts(activeBoostCount)
                .subscriptionByPlan(subscriptionByPlan)
                .boostByPackage(boostByPackage)
                .monthlyTrend(monthlyTrend)
                .build();
    }

    private BigDecimal sumSubscriptionRevenue(List<OrganiserSubscription> subscriptions) {
        return subscriptions.stream()
                .map(s -> s.getPlan().getMonthlyPrice())
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private Double calculateGrowthPercent(BigDecimal lastMonth, BigDecimal thisMonth) {
        if (lastMonth == null || lastMonth.compareTo(BigDecimal.ZERO) == 0) {
            if (thisMonth != null && thisMonth.compareTo(BigDecimal.ZERO) > 0) {
                return 100.0;
            }
            return 0.0;
        }
        return thisMonth.subtract(lastMonth)
                .divide(lastMonth, 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .doubleValue();
    }

    private Map<String, PlanStats> calculateSubscriptionByPlan(LocalDateTime now) {
        Map<String, PlanStats> result = new LinkedHashMap<>();

        List<Object[]> planData = subscriptionRepository.countAndActiveByPlan(now);
        Map<SubscriptionPlan, Object[]> planMap = new HashMap<>();
        for (Object[] row : planData) {
            planMap.put((SubscriptionPlan) row[0], row);
        }

        for (SubscriptionPlan plan : SubscriptionPlan.values()) {
            if (plan == SubscriptionPlan.FREE) continue;

            Object[] row = planMap.get(plan);
            int count = row != null ? ((Number) row[1]).intValue() : 0;
            long activeCount = row != null ? ((Number) row[2]).longValue() : 0;
            BigDecimal revenue = plan.getMonthlyPrice().multiply(BigDecimal.valueOf(count));
            BigDecimal mrr = plan.getMonthlyPrice().multiply(BigDecimal.valueOf(activeCount));

            result.put(plan.name(), PlanStats.builder()
                    .plan(plan.getDisplayName())
                    .count(count)
                    .revenue(revenue)
                    .monthlyRecurringRevenue(mrr)
                    .build());
        }

        return result;
    }

    private Map<String, PackageStats> calculateBoostByPackage() {
        Map<String, PackageStats> result = new LinkedHashMap<>();

        List<Object[]> packageData = boostRepository.sumRevenueGroupedByPackage();
        Map<BoostPackage, Object[]> packageMap = new HashMap<>();
        for (Object[] row : packageData) {
            packageMap.put((BoostPackage) row[0], row);
        }

        for (BoostPackage pkg : BoostPackage.values()) {
            Object[] row = packageMap.get(pkg);
            int count = row != null ? ((Number) row[1]).intValue() : 0;
            BigDecimal revenue = row != null ? (BigDecimal) row[2] : BigDecimal.ZERO;

            result.put(pkg.name(), PackageStats.builder()
                    .packageName(pkg.getDisplayName())
                    .count(count)
                    .revenue(revenue)
                    .build());
        }

        return result;
    }

    private List<MonthlyRevenue> calculateMonthlyTrend() {
        List<MonthlyRevenue> trend = new ArrayList<>();
        YearMonth current = YearMonth.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM");

        YearMonth earliest = current.minusMonths(11);
        LocalDateTime windowStart = earliest.atDay(1).atStartOfDay();
        LocalDateTime windowEnd = current.atEndOfMonth().atTime(23, 59, 59).plusSeconds(1);

        List<EventBoost> windowBoosts = boostRepository.findPaidBoostsBetween(windowStart, windowEnd);
        List<OrganiserSubscription> windowSubs = subscriptionRepository.findPaidSubscriptionsBetween(windowStart, windowEnd);

        for (int i = 11; i >= 0; i--) {
            YearMonth month = current.minusMonths(i);
            LocalDateTime start = month.atDay(1).atStartOfDay();
            LocalDateTime end = month.atEndOfMonth().atTime(23, 59, 59);

            BigDecimal boostRev = windowBoosts.stream()
                    .filter(b -> !b.getPaidAt().isBefore(start) && !b.getPaidAt().isAfter(end))
                    .map(EventBoost::getAmount)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            BigDecimal subRev = windowSubs.stream()
                    .filter(s -> !s.getStartDate().isBefore(start) && !s.getStartDate().isAfter(end))
                    .map(s -> s.getPlan().getMonthlyPrice())
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            trend.add(MonthlyRevenue.builder()
                    .month(month.format(formatter))
                    .subscriptionRevenue(subRev)
                    .boostRevenue(boostRev)
                    .totalRevenue(subRev.add(boostRev))
                    .build());
        }

        return trend;
    }
}
