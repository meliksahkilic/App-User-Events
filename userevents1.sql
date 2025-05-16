	-- Creating Table
USE user_data; CREATE TABLE user_events (
    event_id VARCHAR(255) PRIMARY KEY,
    user_id VARCHAR(255),
    event_name ENUM('PageView', 'Download', 'Install', 'HardPaywall', 'Purchase'),
    platform ENUM('ios', 'android'),
    device_type VARCHAR(255),
    timestamp TIMESTAMP
);

ALTER TABLE user_events 
MODIFY COLUMN event_name ENUM('PageView', 'Download', 'Install', 'HardPaywall', 'Purchase');


	-- Loading our dataset
USE user_data;
LOAD DATA LOCAL INFILE '/Users/computer/Desktop/Scripts/user_events2.csv'
INTO TABLE user_events
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


SELECT COUNT(*) FROM user_events;
SELECT * FROM user_events LIMIT 10;
SHOW WARNINGS;
SHOW ERRORS;



USE user_data; SELECT COUNT(*) FROM user_events;

SELECT * FROM user_events;

select version();


 -- Funnel Anaylsis
USE user_data;


DROP TEMPORARY TABLE IF EXISTS user_funnel;
DROP TEMPORARY TABLE IF EXISTS filtered_funnel;

-- Creating the 'user_funnel' Temporary Table
CREATE TEMPORARY TABLE user_funnel AS
SELECT
    user_id,
    platform,
    MIN(CASE WHEN event_name = 'PageView' THEN timestamp END) AS pageview_time,
    MIN(CASE WHEN event_name = 'Download' THEN timestamp END) AS download_time,
    MIN(CASE WHEN event_name = 'Install' THEN timestamp END) AS install_time
FROM user_events
WHERE event_name IN ('PageView', 'Download', 'Install')
GROUP BY user_id, platform;

-- Check if 'user_funnel' Table Created Successfully
SELECT * FROM user_funnel LIMIT 5;

-- Create the 'filtered_funnel' Temporary Table
CREATE TEMPORARY TABLE filtered_funnel AS
SELECT
    user_id,
    platform,
    pageview_time,
    download_time,
    install_time,
    
    -- Check if Download happened within 72 hours of PageView
    CASE 
        WHEN download_time IS NOT NULL 
        AND download_time <= pageview_time + INTERVAL 72 HOUR 
        THEN 1 ELSE 0 
    END AS converted_download,
    
    -- Check if Install happened within 72 hours of Download
    CASE 
        WHEN install_time IS NOT NULL 
        AND install_time <= download_time + INTERVAL 72 HOUR 
        THEN 1 ELSE 0 
    END AS converted_install
FROM user_funnel;

-- Check if 'filtered_funnel' Table Created Successfully
SELECT * FROM filtered_funnel LIMIT 5;

-- Performing the Funnel Analysis Query
SELECT 
    platform,
    COUNT(DISTINCT user_id) AS total_users,
    COUNT(pageview_time) AS pageviews,
    COUNT(download_time) AS downloads,
    COUNT(install_time) AS installs,
    
    -- Valid conversions within 72 hours using conditional aggregation
    SUM(CASE WHEN converted_download = 1 THEN 1 ELSE 0 END) AS valid_downloads,
    SUM(CASE WHEN converted_install = 1 THEN 1 ELSE 0 END) AS valid_installs,
    
    -- Conversion Rates
    ROUND(SUM(CASE WHEN converted_download = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(pageview_time), 2) AS pageview_to_download_rate,
    ROUND(SUM(CASE WHEN converted_install = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(download_time), 2) AS download_to_install_rate
FROM filtered_funnel
GROUP BY platform;


SHOW Tables;
SELECT * FROM user_events LIMIT 10;


SELECT 
    platform,
    COUNT(DISTINCT user_id) AS total_users,
    COUNT(CASE WHEN event_name = 'PageView' THEN 1 END) AS pageviews,
    COUNT(CASE WHEN event_name = 'Download' THEN 1 END) AS downloads,
    COUNT(CASE WHEN event_name = 'Install' THEN 1 END) AS installs,
    ROUND(COUNT(CASE WHEN event_name = 'Download' THEN 1 END) * 100.0 / COUNT(CASE WHEN event_name = 'PageView' THEN 1 END), 2) AS pageview_to_download_rate,
    ROUND(COUNT(CASE WHEN event_name = 'Install' THEN 1 END) * 100.0 / COUNT(CASE WHEN event_name = 'Download' THEN 1 END), 2) AS download_to_install_rate
FROM user_events
WHERE event_name IN ('PageView', 'Download', 'Install')
GROUP BY platform;

