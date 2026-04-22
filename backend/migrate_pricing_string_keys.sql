USE luma_db;
GO

-- Previously the pricing config tables stored package_key/plan_key as an enum column
-- (@Enumerated(EnumType.STRING) BoostPackage|SubscriptionPlan). Hibernate generated
-- CHECK constraints restricting the values to the four enum names. Now that the
-- JPA mapping treats the key as a free-form String so admins can add custom tiers,
-- those CHECK constraints block any non-canonical key. Drop them.
--
-- Canonical tiers are still protected at the service layer (BoostPackageConfigService.delete
-- / SubscriptionPlanConfigService.delete rejects deletion of enum-backed keys).

DECLARE @name NVARCHAR(256);

SELECT @name = cc.name
FROM sys.check_constraints cc
JOIN sys.columns c
  ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
WHERE cc.parent_object_id = OBJECT_ID('dbo.boost_package_config')
  AND c.name = 'package_key';

IF @name IS NOT NULL
BEGIN
    PRINT 'Dropping CHECK constraint on boost_package_config.package_key: ' + @name;
    EXEC('ALTER TABLE dbo.boost_package_config DROP CONSTRAINT ' + @name);
END
ELSE
    PRINT 'No stale CHECK constraint on boost_package_config.package_key';

SET @name = NULL;
SELECT @name = cc.name
FROM sys.check_constraints cc
JOIN sys.columns c
  ON c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id
WHERE cc.parent_object_id = OBJECT_ID('dbo.subscription_plan_config')
  AND c.name = 'plan_key';

IF @name IS NOT NULL
BEGIN
    PRINT 'Dropping CHECK constraint on subscription_plan_config.plan_key: ' + @name;
    EXEC('ALTER TABLE dbo.subscription_plan_config DROP CONSTRAINT ' + @name);
END
ELSE
    PRINT 'No stale CHECK constraint on subscription_plan_config.plan_key';

-- Grow key columns from VARCHAR(20) → VARCHAR(40) to match new entity declaration.
ALTER TABLE dbo.boost_package_config     ALTER COLUMN package_key VARCHAR(40) NOT NULL;
ALTER TABLE dbo.subscription_plan_config ALTER COLUMN plan_key    VARCHAR(40) NOT NULL;

PRINT 'Migration complete — custom tier keys now accepted by the DB.';
GO
