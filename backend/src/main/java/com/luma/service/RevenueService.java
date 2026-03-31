package com.luma.service;

import com.luma.dto.response.RevenueStatsResponse;
import com.luma.dto.response.RevenueStatsResponse.*;
import com.luma.entity.EventBoost;
import com.luma.entity.OrganiserSubscription;
import com.luma.entity.enums.BoostPackage;
import com.luma.entity.enums.BoostStatus;
import com.luma.entity.enums.SubscriptionPlan;
import com.luma.repository.EventBoostRepository;
import com.luma.repository.OrganiserSubscriptionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

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

    public RevenueStatsResponse getRevenueStats() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime startOfMonth = now.withDayOfMonth(1).withHour(0).withMinute(0).withSecond(0);
        LocalDateTime startOfLastMonth = startOfMonth.minusMonths(1);
        LocalDateTime endOfLastMonth = startOfMonth.minusSeconds(1);

        List<EventBoost> allBoosts = boostRepository.findAll().stream()
                .filter(b -> b.getPaidAt() != null && b.getAmount() != null)
                .collect(Collectors.toList());

        List<OrganiserSubscription> allSubscriptions = subscriptionRepository.findAll().stream()
                .filter(s -> s.getStartDate() != null && s.getPlan() != SubscriptionPlan.FREE)
                .collect(Collectors.toList());

        BigDecimal totalBoostRevenue = allBoosts.stream()
                .map(EventBoost::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal totalSubscriptionRevenue = allSubscriptions.stream()
                .map(this::calculateSubscriptionRevenue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal totalRevenue = totalBoostRevenue.add(totalSubscriptionRevenue);

        BigDecimal monthlyBoostRevenue = allBoosts.stream()
                .filter(b -> b.getPaidAt() != null && b.getPaidAt().isAfter(startOfMonth))
                .map(EventBoost::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal monthlySubscriptionRevenue = allSubscriptions.stream()
                .filter(s -> s.getStartDate() != null && s.getStartDate().isAfter(startOfMonth))
                .map(this::calculateSubscriptionRevenue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal monthlyRevenue = monthlyBoostRevenue.add(monthlySubscriptionRevenue);

        BigDecimal lastMonthBoostRevenue = allBoosts.stream()
                .filter(b -> b.getPaidAt() != null &&
                        b.getPaidAt().isAfter(startOfLastMonth) &&
                        b.getPaidAt().isBefore(startOfMonth))
                .map(EventBoost::getAmount)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal lastMonthSubscriptionRevenue = allSubscriptions.stream()
                .filter(s -> s.getStartDate() != null &&
                        s.getStartDate().isAfter(startOfLastMonth) &&
                        s.getStartDate().isBefore(startOfMonth))
                .map(this::calculateSubscriptionRevenue)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        BigDecimal lastMonthRevenue = lastMonthBoostRevenue.add(lastMonthSubscriptionRevenue);

        Double revenueGrowth = calculateGrowthPercent(lastMonthRevenue, monthlyRevenue);
        Double subscriptionGrowth = calculateGrowthPercent(lastMonthSubscriptionRevenue, monthlySubscriptionRevenue);
        Double boostGrowth = calculateGrowthPercent(lastMonthBoostRevenue, monthlyBoostRevenue);

        int totalSubscriptionCount = allSubscriptions.size();
        int activeSubscriptionCount = (int) allSubscriptions.stream()
                .filter(OrganiserSubscription::isValid)
                .count();
        int totalBoostCount = allBoosts.size();
        int activeBoostCount = (int) allBoosts.stream()
                .filter(b -> b.getStatus() == BoostStatus.ACTIVE && b.isActive())
                .count();

        Map<String, PlanStats> subscriptionByPlan = calculateSubscriptionByPlan(allSubscriptions);

        Map<String, PackageStats> boostByPackage = calculateBoostByPackage(allBoosts);

        List<MonthlyRevenue> monthlyTrend = calculateMonthlyTrend(allBoosts, allSubscriptions);

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

    private BigDecimal calculateSubscriptionRevenue(OrganiserSubscription subscription) {
        if (subscription.getPlan() == SubscriptionPlan.FREE) {
            return BigDecimal.ZERO;
        }
        return subscription.getPlan().getMonthlyPrice();
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

    private Map<String, PlanStats> calculateSubscriptionByPlan(List<OrganiserSubscription> subscriptions) {
        Map<String, PlanStats> result = new LinkedHashMap<>();

        for (SubscriptionPlan plan : SubscriptionPlan.values()) {
            if (plan == SubscriptionPlan.FREE) continue;

            List<OrganiserSubscription> planSubs = subscriptions.stream()
                    .filter(s -> s.getPlan() == plan)
                    .collect(Collectors.toList());

            int count = planSubs.size();
            BigDecimal revenue = planSubs.stream()
                    .map(this::calculateSubscriptionRevenue)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            long activeCount = planSubs.stream()
                    .filter(OrganiserSubscription::isValid)
                    .count();
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

    private Map<String, PackageStats> calculateBoostByPackage(List<EventBoost> boosts) {
        Map<String, PackageStats> result = new LinkedHashMap<>();

        for (BoostPackage pkg : BoostPackage.values()) {
            List<EventBoost> pkgBoosts = boosts.stream()
                    .filter(b -> b.getBoostPackage() == pkg)
                    .collect(Collectors.toList());

            int count = pkgBoosts.size();
            BigDecimal revenue = pkgBoosts.stream()
                    .map(EventBoost::getAmount)
                    .filter(Objects::nonNull)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            result.put(pkg.name(), PackageStats.builder()
                    .packageName(pkg.getDisplayName())
                    .count(count)
                    .revenue(revenue)
                    .build());
        }

        return result;
    }

    private List<MonthlyRevenue> calculateMonthlyTrend(List<EventBoost> boosts, List<OrganiserSubscription> subscriptions) {
        List<MonthlyRevenue> trend = new ArrayList<>();
        YearMonth current = YearMonth.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM");

        for (int i = 11; i >= 0; i--) {
            YearMonth month = current.minusMonths(i);
            LocalDateTime start = month.atDay(1).atStartOfDay();
            LocalDateTime end = month.atEndOfMonth().atTime(23, 59, 59);

            BigDecimal boostRev = boosts.stream()
                    .filter(b -> b.getPaidAt() != null &&
                            !b.getPaidAt().isBefore(start) &&
                            !b.getPaidAt().isAfter(end))
                    .map(EventBoost::getAmount)
                    .filter(Objects::nonNull)
                    .reduce(BigDecimal.ZERO, BigDecimal::add);

            BigDecimal subRev = subscriptions.stream()
                    .filter(s -> s.getStartDate() != null &&
                            !s.getStartDate().isBefore(start) &&
                            !s.getStartDate().isAfter(end))
                    .map(this::calculateSubscriptionRevenue)
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
