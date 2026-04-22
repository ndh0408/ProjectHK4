USE luma_db;
GO

SET IDENTITY_INSERT cities ON;

INSERT INTO cities (id, name, continent, country, active) VALUES
 (1,  N'Ho Chi Minh',  N'Asia',          N'Vietnam',     1),
 (2,  N'Ha Noi',       N'Asia',          N'Vietnam',     1),
 (3,  N'Da Nang',      N'Asia',          N'Vietnam',     1),
 (4,  N'Bangkok',      N'Asia',          N'Thailand',    1),
 (5,  N'Singapore',    N'Asia',          N'Singapore',   1),
 (6,  N'Tokyo',        N'Asia',          N'Japan',       1),
 (7,  N'Seoul',        N'Asia',          N'South Korea', 1),
 (8,  N'New York',     N'North America', N'USA',         1),
 (9,  N'Los Angeles',  N'North America', N'USA',         1),
 (10, N'London',       N'Europe',        N'UK',          1),
 (11, N'Paris',        N'Europe',        N'France',      1),
 (12, N'Berlin',       N'Europe',        N'Germany',     1),
 (13, N'Sydney',       N'Oceania',       N'Australia',   1);

SET IDENTITY_INSERT cities OFF;
GO

SELECT COUNT(*) AS cities_seeded FROM cities;
GO
