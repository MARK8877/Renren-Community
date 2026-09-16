CREATE TABLE IF NOT EXISTS external_home_posts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    source VARCHAR(64) NOT NULL,
    external_id VARCHAR(500) NOT NULL,
    author VARCHAR(255) NOT NULL,
    role VARCHAR(255) NOT NULL,
    content VARCHAR(1000) NOT NULL,
    tags_json JSON NOT NULL,
    source_url VARCHAR(1500) NOT NULL,
    source_order INT NOT NULL DEFAULT 0,
    published_at DATETIME(3) NULL,
    scraped_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    updated_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
    PRIMARY KEY (id),
    UNIQUE KEY uk_external_home_posts_source_external (source, external_id),
    KEY idx_external_home_posts_feed (scraped_at, source_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
