-- ====================================
-- SEED DATA: INSERT 20 COUPONS
-- ====================================
-- Purpose: Add sample coupon data for testing and development
-- This script inserts 20 different coupons with various discount types and conditions

DECLARE @adminUserId UNIQUEIDENTIFIER;
DECLARE @eventId UNIQUEIDENTIFIER;

-- Get the first admin user or any user
SELECT TOP 1 @adminUserId = id FROM users WHERE deleted = 0;

-- Get the first event (optional, can be NULL)
SELECT TOP 1 @eventId = id FROM events WHERE deleted = 0;

-- If no users exist, you need to create one first or update the script
IF @adminUserId IS NULL
BEGIN
    PRINT 'ERROR: No users found in database. Please create at least one user first.';
    RETURN;
END;

-- Insert 20 sample coupons
BEGIN TRY
    INSERT INTO coupons (
        id, code, description, discount_type, discount_value, 
        max_discount_amount, min_order_amount, event_id, created_by,
        status, max_usage_count, used_count, max_usage_per_user,
        valid_from, valid_until, created_at, updated_at
    ) VALUES
    
    -- 1. Welcome Discount - 10% off any order
    (NEWID(), 'WELCOME10', N'10% discount on first purchase', 'PERCENTAGE', 10.00, NULL, NULL, @eventId, @adminUserId, 'ACTIVE', 1000, 0, 1, GETDATE(), DATEADD(day, 30, GETDATE()), GETDATE(), GETDATE()),
    
    -- 2. Summer Sale - 20% off with $50 minimum
    (NEWID(), 'SUMMER20', N'20% off on all items during summer sale', 'PERCENTAGE', 20.00, NULL, 50.00, @eventId, @adminUserId, 'ACTIVE', 500, 0, 5, GETDATE(), DATEADD(day, 60, GETDATE()), GETDATE(), GETDATE()),
    
    -- 3. Fixed $5 discount
    (NEWID(), 'SAVE5', N'Get $5 off your order', 'FIXED_AMOUNT', 5.00, NULL, 20.00, @eventId, @adminUserId, 'ACTIVE', 2000, 0, 2, GETDATE(), DATEADD(day, 45, GETDATE()), GETDATE(), GETDATE()),
    
    -- 4. Fixed $10 discount
    (NEWID(), 'SAVE10', N'Get $10 off on orders over $50', 'FIXED_AMOUNT', 10.00, NULL, 50.00, @eventId, @adminUserId, 'ACTIVE', 1500, 0, 1, GETDATE(), DATEADD(day, 90, GETDATE()), GETDATE(), GETDATE()),
    
    -- 5. VIP Discount - 25% off with max $100 discount
    (NEWID(), 'VIP25', N'VIP members get 25% off with max $100 discount', 'PERCENTAGE', 25.00, 100.00, NULL, @eventId, @adminUserId, 'ACTIVE', 300, 0, NULL, GETDATE(), DATEADD(day, 180, GETDATE()), GETDATE(), GETDATE()),
    
    -- 6. Expired Coupon - Demo only
    (NEWID(), 'EXPIRED30', N'30% off - This coupon has expired', 'PERCENTAGE', 30.00, NULL, NULL, @eventId, @adminUserId, 'EXPIRED', 500, 500, 1, DATEADD(day, -60, GETDATE()), DATEADD(day, -1, GETDATE()), DATEADD(day, -60, GETDATE()), GETDATE()),
    
    -- 7. New Year Special - 15% off
    (NEWID(), 'NEWYEAR15', N'New Year Special: 15% off everything', 'PERCENTAGE', 15.00, 50.00, NULL, @eventId, @adminUserId, 'ACTIVE', 5000, 3421, 2, DATEADD(day, -10, GETDATE()), DATEADD(day, 20, GETDATE()), GETDATE(), GETDATE()),
    
    -- 8. Fixed $20 discount - Limited usage
    (NEWID(), 'PROMO20', N'Limited time: $20 off on qualifying purchases', 'FIXED_AMOUNT', 20.00, NULL, 100.00, @eventId, @adminUserId, 'ACTIVE', 100, 45, 1, GETDATE(), DATEADD(day, 14, GETDATE()), GETDATE(), GETDATE()),
    
    -- 9. Birthday Bonus - 18% off
    (NEWID(), 'BIRTHDAY18', N'Birthday month special - 18% discount', 'PERCENTAGE', 18.00, NULL, NULL, @eventId, @adminUserId, 'ACTIVE', 2000, 0, 1, GETDATE(), DATEADD(day, 120, GETDATE()), GETDATE(), GETDATE()),
    
    -- 10. Flash Sale - 35% off (High discount, limited)
    (NEWID(), 'FLASH35', N'Flash Sale: 35% off for 24 hours only', 'PERCENTAGE', 35.00, 75.00, NULL, @eventId, @adminUserId, 'ACTIVE', 50, 28, 1, GETDATE(), DATEADD(hour, 24, GETDATE()), GETDATE(), GETDATE()),
    
    -- 11. Fixed $50 discount - Premium
    (NEWID(), 'PREMIUM50', N'Premium member exclusive: $50 off', 'FIXED_AMOUNT', 50.00, NULL, 200.00, @eventId, @adminUserId, 'ACTIVE', 200, 0, 1, GETDATE(), DATEADD(day, 365, GETDATE()), GETDATE(), GETDATE()),
    
    -- 12. Referral Bonus - 12% off
    (NEWID(), 'REFER12', N'Referral bonus - 12% for you and your friend', 'PERCENTAGE', 12.00, NULL, NULL, @eventId, @adminUserId, 'ACTIVE', 3000, 1200, 1, GETDATE(), DATEADD(day, 180, GETDATE()), GETDATE(), GETDATE()),
    
    -- 13. Student Discount - 22% off
    (NEWID(), 'STUDENT22', N'Valid student ID required - 22% off', 'PERCENTAGE', 22.00, NULL, NULL, @eventId, @adminUserId, 'ACTIVE', 1000, 0, 5, GETDATE(), DATEADD(day, 365, GETDATE()), GETDATE(), GETDATE()),
    
    -- 14. Bundle Deal - Fixed $15
    (NEWID(), 'BUNDLE15', N'Buy 2+ items and save $15', 'FIXED_AMOUNT', 15.00, NULL, 75.00, @eventId, @adminUserId, 'ACTIVE', 800, 0, 2, GETDATE(), DATEADD(day, 60, GETDATE()), GETDATE(), GETDATE()),
    
    -- 15. Corporate - 28% off
    (NEWID(), 'CORPORATE28', N'Corporate/Business accounts - 28% discount', 'PERCENTAGE', 28.00, 200.00, NULL, @eventId, @adminUserId, 'ACTIVE', 150, 0, 5, GETDATE(), DATEADD(day, 365, GETDATE()), GETDATE(), GETDATE()),
    
    -- 16. Weekend Special - 16% off
    (NEWID(), 'WEEKEND16', N'Weekend only: 16% off', 'PERCENTAGE', 16.00, NULL, 40.00, @eventId, @adminUserId, 'ACTIVE', 2500, 340, 1, GETDATE(), DATEADD(day, 90, GETDATE()), GETDATE(), GETDATE()),
    
    -- 17. Loyalty Reward - 19% off
    (NEWID(), 'LOYAL19', N'Thank you for being loyal - 19% discount', 'PERCENTAGE', 19.00, NULL, NULL, @eventId, @adminUserId, 'ACTIVE', 5000, 4234, 10, GETDATE(), DATEADD(day, 180, GETDATE()), GETDATE(), GETDATE()),
    
    -- 18. Clearance - Fixed $25
    (NEWID(), 'CLEAR25', N'Clearance items - $25 off clearance purchases', 'FIXED_AMOUNT', 25.00, NULL, 100.00, @eventId, @adminUserId, 'ACTIVE', 300, 89, 1, GETDATE(), DATEADD(day, 30, GETDATE()), GETDATE(), GETDATE()),
    
    -- 19. Free Shipping - 8% effective (symbolic, represents free shipping)
    (NEWID(), 'FREESHIP', N'Free shipping on orders over $35', 'PERCENTAGE', 8.00, NULL, 35.00, @eventId, @adminUserId, 'ACTIVE', 10000, 5432, 2, GETDATE(), DATEADD(day, 180, GETDATE()), GETDATE(), GETDATE()),
    
    -- 20. Grand Opening - 32% off (Limited time)
    (NEWID(), 'OPENING32', N'Grand Opening Special - 32% off everything', 'PERCENTAGE', 32.00, 150.00, NULL, @eventId, @adminUserId, 'ACTIVE', 999, 645, 3, DATEADD(day, -5, GETDATE()), DATEADD(day, 30, GETDATE()), GETDATE(), GETDATE());
    
    PRINT 'SUCCESS: 20 coupons have been inserted successfully!';
END TRY
BEGIN CATCH
    PRINT 'ERROR: Failed to insert coupons';
    PRINT ERROR_MESSAGE();
    ROLLBACK TRANSACTION;
END CATCH;

-- Verify inserted data
SELECT 
    id,
    code,
    description,
    discount_type,
    discount_value,
    status,
    valid_until,
    max_usage_count,
    used_count,
    created_at
FROM coupons 
WHERE code IN ('WELCOME10', 'SUMMER20', 'SAVE5', 'SAVE10', 'VIP25', 'EXPIRED30', 
               'NEWYEAR15', 'PROMO20', 'BIRTHDAY18', 'FLASH35', 'PREMIUM50', 'REFER12',
               'STUDENT22', 'BUNDLE15', 'CORPORATE28', 'WEEKEND16', 'LOYAL19', 'CLEAR25',
               'FREESHIP', 'OPENING32')
ORDER BY created_at DESC;
