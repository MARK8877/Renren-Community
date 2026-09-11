CREATE TABLE IF NOT EXISTS video_scrape_jobs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    status ENUM('running','succeeded','failed') NOT NULL,
    trigger_type ENUM('scheduled','manual') NOT NULL,
    started_at DATETIME(3) NOT NULL,
    finished_at DATETIME(3) NULL,
    error_message TEXT NULL,
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    KEY idx_video_scrape_jobs_created_at (created_at),
    KEY idx_video_scrape_jobs_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
