USE luma_db;
GO

-- Boost package config — mirror enum defaults (BoostPackage.java). Admin can later edit via
-- /api/admin/pricing/boost-packages/{key}. Idempotent: inserts only keys not already present.
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'boost_package_config')
BEGIN
    CREATE TABLE boost_package_config (
        package_key NVARCHAR(20) NOT NULL PRIMARY KEY,
        display_name NVARCHAR(100) NOT NULL,
        price_usd DECIMAL(10,2) NOT NULL,
        duration_days INT NOT NULL,
        boost_multiplier FLOAT NOT NULL,
        badge_text NVARCHAR(50) NOT NULL,
        featured_in_category BIT NOT NULL DEFAULT 0,
        featured_on_home BIT NOT NULL DEFAULT 0,
        priority_in_search BIT NOT NULL DEFAULT 0,
        home_banner BIT NOT NULL DEFAULT 0,
        active BIT NOT NULL DEFAULT 1,
        sort_order INT NOT NULL DEFAULT 0,
        created_at DATETIME2 NULL,
        updated_at DATETIME2 NULL
    );
END

MERGE boost_package_config AS T
USING (VALUES
    (N'VIP',      N'VIP',      99.99, 30, 5.0, N'VIP',      1, 1, 1, 1, 1, 0, SYSUTCDATETIME(), SYSUTCDATETIME()),
    (N'PREMIUM',  N'Premium',  49.99, 30, 3.0, N'PREMIUM',  1, 1, 1, 0, 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
    (N'STANDARD', N'Standard', 24.99, 14, 2.0, N'FEATURED', 1, 0, 1, 0, 1, 2, SYSUTCDATETIME(), SYSUTCDATETIME()),
    (N'BASIC',    N'Basic',     9.99,  7, 1.5, N'BOOSTED',  0, 0, 1, 0, 1, 3, SYSUTCDATETIME(), SYSUTCDATETIME())
) AS S (package_key, display_name, price_usd, duration_days, boost_multiplier, badge_text,
        featured_in_category, featured_on_home, priority_in_search, home_banner, active, sort_order,
        created_at, updated_at)
ON T.package_key = S.package_key
WHEN NOT MATCHED THEN
    INSERT (package_key, display_name, price_usd, duration_days, boost_multiplier, badge_text,
            featured_in_category, featured_on_home, priority_in_search, home_banner,
            active, sort_order, created_at, updated_at)
    VALUES (S.package_key, S.display_name, S.price_usd, S.duration_days, S.boost_multiplier, S.badge_text,
            S.featured_in_category, S.featured_on_home, S.priority_in_search, S.home_banner,
            S.active, S.sort_order, S.created_at, S.updated_at);
GO

-- Subscription plan config — mirror enum defaults (SubscriptionPlan.java).
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'subscription_plan_config')
BEGIN
    CREATE TABLE subscription_plan_config (
        plan_key NVARCHAR(20) NOT NULL PRIMARY KEY,
        display_name NVARCHAR(100) NOT NULL,
        monthly_price_usd DECIMAL(10,2) NOT NULL,
        max_events_per_month INT NOT NULL,
        boost_discount_percent INT NOT NULL,
        active BIT NOT NULL DEFAULT 1,
        sort_order INT NOT NULL DEFAULT 0,
        created_at DATETIME2 NULL,
        updated_at DATETIME2 NULL
    );
END

MERGE subscription_plan_config AS T
USING (VALUES
    (N'FREE',     N'Free',      0.00,  3,  0, 1, 0, SYSUTCDATETIME(), SYSUTCDATETIME()),
    (N'STANDARD', N'Standard', 19.99, 10, 10, 1, 1, SYSUTCDATETIME(), SYSUTCDATETIME()),
    (N'PREMIUM',  N'Premium',  49.99, 30, 20, 1, 2, SYSUTCDATETIME(), SYSUTCDATETIME()),
    (N'VIP',      N'VIP',      99.99, -1, 30, 1, 3, SYSUTCDATETIME(), SYSUTCDATETIME())
) AS S (plan_key, display_name, monthly_price_usd, max_events_per_month,
        boost_discount_percent, active, sort_order, created_at, updated_at)
ON T.plan_key = S.plan_key
WHEN NOT MATCHED THEN
    INSERT (plan_key, display_name, monthly_price_usd, max_events_per_month,
            boost_discount_percent, active, sort_order, created_at, updated_at)
    VALUES (S.plan_key, S.display_name, S.monthly_price_usd, S.max_events_per_month,
            S.boost_discount_percent, S.active, S.sort_order, S.created_at, S.updated_at);
GO

SELECT 'boost_package_config' AS tbl, package_key, display_name, price_usd, duration_days, active
  FROM boost_package_config ORDER BY sort_order;
SELECT 'subscription_plan_config' AS tbl, plan_key, display_name, monthly_price_usd, max_events_per_month, active
  FROM subscription_plan_config ORDER BY sort_order;
GO
