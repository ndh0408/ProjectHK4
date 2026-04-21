-- =====================================================================
-- LUMA demo seed — ndh0408@gmail.com (user Huy presenting)
-- Creates 5 completed past events with APPROVED + checked-in registrations
--   - 3 events have certificates already generated (demo "My Certificates")
--   - 2 events have NO certificate yet (demo live certificate generation)
--   - 2 events have reviews already written (demo "My Reviews" listing)
--   - 3 events have NO review yet (demo live review writing)
-- Idempotent: re-runs are no-ops while the [HUY-DEMO] marker still exists.
-- =====================================================================
SET NOCOUNT ON;

DECLARE @userId  UNIQUEIDENTIFIER = '5CB4D57D-AC51-4469-82CA-D72A80C4E7DA'; -- ndh0408@gmail.com
DECLARE @org1    UNIQUEIDENTIFIER = 'F968FB17-6462-449C-BEDF-0C5F20B61387'; -- StartupVN Hub
DECLARE @org2    UNIQUEIDENTIFIER = '0DEB7EA4-4523-4DA9-A892-A44805CE67AF'; -- Sunflower Media
DECLARE @org3    UNIQUEIDENTIFIER = '212F39C2-F81F-4141-AC14-D1B0DDDEFCD2'; -- TechViet Events
DECLARE @now     DATETIME2 = SYSUTCDATETIME();

IF EXISTS (SELECT 1 FROM events WHERE title LIKE N'\[HUY-DEMO\]%' ESCAPE '\')
BEGIN
    PRINT 'Seed already applied — skipping. Delete [HUY-DEMO] events first to re-seed.';
END
ELSE
BEGIN
    DECLARE @e1 UNIQUEIDENTIFIER = NEWID();
    DECLARE @e2 UNIQUEIDENTIFIER = NEWID();
    DECLARE @e3 UNIQUEIDENTIFIER = NEWID();
    DECLARE @e4 UNIQUEIDENTIFIER = NEWID();
    DECLARE @e5 UNIQUEIDENTIFIER = NEWID();

    INSERT INTO events (id, title, description, image_url, start_time, end_time, registration_deadline,
        venue, address, ticket_price, is_free, capacity, approved_count, status, visibility,
        requires_approval, recurrence_type, organiser_id, category_id, city_id,
        created_at, updated_at, deleted)
    VALUES
    (@e1, N'[HUY-DEMO] Vietnam AI Summit — Spring 2026',
        N'Hội nghị AI hàng đầu Việt Nam với các diễn giả từ OpenAI, Google DeepMind và các startup AI nội địa. 6 giờ keynote + workshop + networking.',
        N'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=1200',
        DATEADD(DAY, -30, @now), DATEADD(HOUR, 6, DATEADD(DAY, -30, @now)), DATEADD(DAY, -32, @now),
        N'Saigon Innovation Hub', N'273 Điện Biên Phủ, Quận 3, TP.HCM', 0, 1, 200, 1, 'COMPLETED', 'PUBLIC',
        0, 'NONE', @org3, 2, 1,
        DATEADD(DAY, -45, @now), DATEADD(DAY, -30, @now), 0),
    (@e2, N'[HUY-DEMO] Climate Tech Founders Night',
        N'Đêm kết nối dành cho founder lĩnh vực khí hậu, năng lượng tái tạo và giải pháp xanh cho Đồng bằng sông Cửu Long.',
        N'https://images.unsplash.com/photo-1509391366360-2e959784a276?w=1200',
        DATEADD(DAY, -20, @now), DATEADD(HOUR, 4, DATEADD(DAY, -20, @now)), DATEADD(DAY, -22, @now),
        N'Dreamplex Center', N'21 Nguyễn Trung Ngạn, Quận 1, TP.HCM', 0, 1, 120, 1, 'COMPLETED', 'PUBLIC',
        0, 'NONE', @org1, 10, 1,
        DATEADD(DAY, -40, @now), DATEADD(DAY, -20, @now), 0),
    (@e3, N'[HUY-DEMO] Web3 Builders Meetup #12',
        N'Cộng đồng Web3 Việt Nam chia sẻ kinh nghiệm xây dựng sản phẩm on-chain: từ smart contract tới UX thực tế.',
        N'https://images.unsplash.com/photo-1639762681485-074b7f938ba0?w=1200',
        DATEADD(DAY, -14, @now), DATEADD(HOUR, 3, DATEADD(DAY, -14, @now)), DATEADD(DAY, -16, @now),
        N'Toong Coworking', N'8 Tràng Thi, Hoàn Kiếm, Hà Nội', 0, 1, 80, 1, 'COMPLETED', 'PUBLIC',
        0, 'NONE', @org2, 12, 2,
        DATEADD(DAY, -35, @now), DATEADD(DAY, -14, @now), 0),
    (@e4, N'[HUY-DEMO] Design Sprint Workshop 2026',
        N'Workshop 2 buổi theo phương pháp Design Sprint (Google Ventures) — áp dụng vào case thực tế sản phẩm SaaS.',
        N'https://images.unsplash.com/photo-1552664730-d307ca884978?w=1200',
        DATEADD(DAY, -7, @now), DATEADD(HOUR, 8, DATEADD(DAY, -7, @now)), DATEADD(DAY, -9, @now),
        N'Dreamplex 21 Nguyễn Trung Ngạn', N'21 Nguyễn Trung Ngạn, Quận 1, TP.HCM', 0, 1, 40, 1, 'COMPLETED', 'PUBLIC',
        0, 'NONE', @org3, 14, 1,
        DATEADD(DAY, -30, @now), DATEADD(DAY, -7, @now), 0),
    (@e5, N'[HUY-DEMO] Digital Marketing Masterclass',
        N'Masterclass nửa ngày về content marketing, performance ads và SEO thực chiến năm 2026.',
        N'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=1200',
        DATEADD(DAY, -3, @now), DATEADD(HOUR, 5, DATEADD(DAY, -3, @now)), DATEADD(DAY, -5, @now),
        N'Rex Hotel Ballroom', N'141 Nguyễn Huệ, Quận 1, TP.HCM', 0, 1, 150, 1, 'COMPLETED', 'PUBLIC',
        0, 'NONE', @org1, 2, 1,
        DATEADD(DAY, -25, @now), DATEADD(DAY, -3, @now), 0);

    DECLARE @r1 UNIQUEIDENTIFIER = NEWID();
    DECLARE @r2 UNIQUEIDENTIFIER = NEWID();
    DECLARE @r3 UNIQUEIDENTIFIER = NEWID();
    DECLARE @r4 UNIQUEIDENTIFIER = NEWID();
    DECLARE @r5 UNIQUEIDENTIFIER = NEWID();

    INSERT INTO registrations (id, status, ticket_code, approved_at, checked_in_at, quantity,
        reminder_sent, event_id, user_id, created_at, updated_at)
    VALUES
    (@r1, 'APPROVED', 'HUY-DEMO-T1', DATEADD(DAY, -44, @now), DATEADD(DAY, -30, @now), 1, 1, @e1, @userId, DATEADD(DAY, -44, @now), DATEADD(DAY, -30, @now)),
    (@r2, 'APPROVED', 'HUY-DEMO-T2', DATEADD(DAY, -39, @now), DATEADD(DAY, -20, @now), 1, 1, @e2, @userId, DATEADD(DAY, -39, @now), DATEADD(DAY, -20, @now)),
    (@r3, 'APPROVED', 'HUY-DEMO-T3', DATEADD(DAY, -34, @now), DATEADD(DAY, -14, @now), 1, 1, @e3, @userId, DATEADD(DAY, -34, @now), DATEADD(DAY, -14, @now)),
    (@r4, 'APPROVED', 'HUY-DEMO-T4', DATEADD(DAY, -29, @now), DATEADD(DAY, -7,  @now), 1, 1, @e4, @userId, DATEADD(DAY, -29, @now), DATEADD(DAY, -7,  @now)),
    (@r5, 'APPROVED', 'HUY-DEMO-T5', DATEADD(DAY, -24, @now), DATEADD(DAY, -3,  @now), 1, 1, @e5, @userId, DATEADD(DAY, -24, @now), DATEADD(DAY, -3,  @now));

    INSERT INTO certificates (id, registration_id, certificate_code, certificate_url, generated_at, created_at)
    VALUES
    (NEWID(), @r1, 'CERT-HUYDEMO1', 'https://res.cloudinary.com/demo/raw/upload/luma/certificates/CERT-HUYDEMO1.pdf', DATEADD(DAY, -29, @now), DATEADD(DAY, -29, @now)),
    (NEWID(), @r2, 'CERT-HUYDEMO2', 'https://res.cloudinary.com/demo/raw/upload/luma/certificates/CERT-HUYDEMO2.pdf', DATEADD(DAY, -19, @now), DATEADD(DAY, -19, @now)),
    (NEWID(), @r3, 'CERT-HUYDEMO3', 'https://res.cloudinary.com/demo/raw/upload/luma/certificates/CERT-HUYDEMO3.pdf', DATEADD(DAY, -13, @now), DATEADD(DAY, -13, @now));

    INSERT INTO reviews (id, user_id, event_id, rating, comment, flagged, toxicity_score, created_at, updated_at)
    VALUES
    (NEWID(), @userId, @e1, 5,
        N'Sự kiện cực kỳ chất lượng! Diễn giả từ OpenAI chia sẻ nhiều insight mới về multimodal AI, phần networking cuối cũng rất hiệu quả.',
        0, 2, DATEADD(DAY, -28, @now), DATEADD(DAY, -28, @now)),
    (NEWID(), @userId, @e3, 4,
        N'Nội dung builder chia sẻ rất thực tế, không sáo rỗng. Trừ 1 sao vì phòng hơi nóng và setup mic chưa ổn định ở session đầu.',
        0, 3, DATEADD(DAY, -12, @now), DATEADD(DAY, -12, @now));

    PRINT '✔ Seeded 5 events + 5 APPROVED checked-in registrations + 3 certificates + 2 reviews for ndh0408@gmail.com';
END
