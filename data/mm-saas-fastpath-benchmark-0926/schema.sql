-- Music Metrics benchmark schema (mirrors DDL from leadlists.php bootstrap)
-- Generated for mm-saas-fastpath-benchmark-0926

USE musicmetrics;

-- users table (minimal for benchmark)
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    credits INT DEFAULT 100,
    shared_for_credits TINYINT DEFAULT 0,
    ghl_api_key VARCHAR(255) DEFAULT NULL,
    ghl_location_id VARCHAR(100) DEFAULT NULL,
    last_active_at DATETIME DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- lead_lists table
CREATE TABLE IF NOT EXISTS lead_lists (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category_group VARCHAR(100) DEFAULT NULL,
    category VARCHAR(100) DEFAULT NULL,
    subcategory VARCHAR(100) DEFAULT NULL,
    source VARCHAR(100) DEFAULT NULL,
    country VARCHAR(12) DEFAULT 'US',
    is_public TINYINT DEFAULT 0,
    public_token VARCHAR(64) DEFAULT NULL,
    icon_class VARCHAR(80) DEFAULT NULL,
    icon_color VARCHAR(40) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE INDEX idx_public_token (public_token),
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- lead_list_items table
CREATE TABLE IF NOT EXISTS lead_list_items (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    list_id INT NOT NULL,
    user_id INT NOT NULL,
    business_id VARCHAR(255),
    business_name VARCHAR(500),
    address VARCHAR(500),
    city VARCHAR(255),
    state VARCHAR(255),
    phone VARCHAR(100),
    website VARCHAR(500),
    rating DECIMAL(3,2),
    review_count INT DEFAULT 0,
    types TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    emails JSON,
    social_media_links JSON,
    notes TEXT,
    status ENUM('cold','warm','hot') DEFAULT 'cold',
    visited_website TINYINT DEFAULT 0,
    visited_social TINYINT DEFAULT 0,
    reached_out TINYINT DEFAULT 0,
    website_visited_at DATETIME NULL,
    social_visited_at DATETIME NULL,
    reached_out_at DATETIME NULL,
    raw_data JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    enriched_at DATETIME NULL DEFAULT NULL,
    visited_socials JSON DEFAULT NULL,
    pipeline_stage VARCHAR(20) DEFAULT 'new',
    outreach_email TINYINT DEFAULT 0,
    outreach_instagram TINYINT DEFAULT 0,
    follow_up_count INT DEFAULT 0,
    first_contacted_at DATETIME NULL DEFAULT NULL,
    last_follow_up_at DATETIME NULL DEFAULT NULL,
    enrichment_status VARCHAR(20) DEFAULT NULL,
    replicate_id VARCHAR(64) DEFAULT NULL,
    ghl_contact_id VARCHAR(100) DEFAULT NULL,
    has_email TINYINT DEFAULT 0,
    has_socials TINYINT DEFAULT 0,
    has_phone TINYINT DEFAULT 0,
    has_website TINYINT DEFAULT 0,
    has_notes TINYINT DEFAULT 0,
    lead_score INT DEFAULT NULL,
    INDEX idx_list (list_id),
    INDEX idx_user (user_id),
    INDEX idx_status (status),
    INDEX idx_list_status (list_id, status),
    INDEX idx_lead_score (lead_score),
    INDEX idx_list_user_created (list_id, user_id, created_at DESC),
    INDEX idx_list_user (list_id, user_id),
    INDEX idx_list_pipeline (list_id, pipeline_stage),
    INDEX idx_list_has_email (list_id, has_email),
    INDEX idx_list_stats_cover (list_id, user_id, status, pipeline_stage, visited_website, visited_social, reached_out, has_email, has_socials, has_phone, has_website, has_notes, outreach_email, outreach_instagram, follow_up_count),
    FULLTEXT idx_search (business_name, address, notes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- lead_list_searches table
CREATE TABLE IF NOT EXISTS lead_list_searches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    list_id INT NOT NULL,
    user_id INT NOT NULL,
    search_query VARCHAR(500),
    state_name VARCHAR(255),
    city VARCHAR(255),
    results_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_list (list_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- scrape_city_jobs table
CREATE TABLE IF NOT EXISTS scrape_city_jobs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    list_id INT NOT NULL,
    country VARCHAR(12) NOT NULL DEFAULT 'US',
    country_code VARCHAR(4) DEFAULT NULL,
    state_name VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    search_query VARCHAR(500) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'queued',
    results_count INT DEFAULT 0,
    error_message VARCHAR(500) DEFAULT NULL,
    locked_at DATETIME DEFAULT NULL,
    started_at DATETIME DEFAULT NULL,
    completed_at DATETIME DEFAULT NULL,
    run_id VARCHAR(64) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_scrape_city_job (user_id, list_id, country, state_name, city, search_query),
    INDEX idx_scrape_status (status, created_at),
    INDEX idx_scrape_user_list (user_id, list_id),
    INDEX idx_scrape_run (run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ghl_connections table
CREATE TABLE IF NOT EXISTS ghl_connections (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    api_key VARCHAR(500) DEFAULT NULL,
    location_id VARCHAR(100) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ghl_import_logs table
CREATE TABLE IF NOT EXISTS ghl_import_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    connection_id INT DEFAULT NULL,
    connection_name VARCHAR(255) DEFAULT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    records_imported INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ghl_import_items table
CREATE TABLE IF NOT EXISTS ghl_import_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    log_id INT NOT NULL,
    ghl_contact_id VARCHAR(100) DEFAULT NULL,
    status VARCHAR(30) DEFAULT 'pending',
    error_message VARCHAR(500) DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_log (log_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- geo_countries table
CREATE TABLE IF NOT EXISTS geo_countries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_code VARCHAR(4) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- geo_cities table
CREATE TABLE IF NOT EXISTS geo_cities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    country_code VARCHAR(4) NOT NULL,
    state_name VARCHAR(255) NOT NULL,
    city VARCHAR(255) NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_country (country_code),
    INDEX idx_state (state_name),
    UNIQUE KEY uniq_city (country_code, state_name, city)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
