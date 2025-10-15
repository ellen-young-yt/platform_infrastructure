"""
Superset Configuration File
Based on Apache Superset official recommendations:
https://superset.apache.org/docs/configuration/configuring-superset/

This file overrides default Superset settings and is loaded via SUPERSET_CONFIG_PATH.
All sensitive values are pulled from environment variables injected by AWS ECS.
"""

import os
from typing import Optional

# -----------------------------------------------------------------------------
# Flask Application Settings
# -----------------------------------------------------------------------------

# SECRET_KEY - Required for session management, CSRF protection, and secure cookies
# This is injected from AWS Secrets Manager via ECS task secrets
SECRET_KEY = os.environ.get("SECRET_KEY")

if not SECRET_KEY:
    raise ValueError(
        "SECRET_KEY environment variable is required. "
        "It should be injected from AWS Secrets Manager."
    )

# -----------------------------------------------------------------------------
# Metadata Database Configuration
# -----------------------------------------------------------------------------

# Build the SQLAlchemy database URI from environment variables
# These are injected from AWS Secrets Manager via ECS task secrets
DATABASE_USER = os.environ.get("DATABASE_USER")
DATABASE_PASSWORD = os.environ.get("DATABASE_PASSWORD")
DATABASE_HOST = os.environ.get("DATABASE_HOST")
DATABASE_PORT = os.environ.get("DATABASE_PORT", "5432")
DATABASE_DB = os.environ.get("DATABASE_DB")

# Validate required database configuration
required_db_vars = {
    "DATABASE_USER": DATABASE_USER,
    "DATABASE_PASSWORD": DATABASE_PASSWORD,
    "DATABASE_HOST": DATABASE_HOST,
    "DATABASE_DB": DATABASE_DB,
}

missing_vars = [key for key, value in required_db_vars.items() if not value]
if missing_vars:
    raise ValueError(
        f"Missing required database environment variables: {', '.join(missing_vars)}. "
        "These should be injected from AWS Secrets Manager."
    )

# SQLAlchemy database URI for metadata storage
SQLALCHEMY_DATABASE_URI = (
    f"postgresql://{DATABASE_USER}:{DATABASE_PASSWORD}"
    f"@{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)

# -----------------------------------------------------------------------------
# Database Connection Pool Settings
# -----------------------------------------------------------------------------

# Connection pool configuration for SQLAlchemy
SQLALCHEMY_POOL_SIZE = 5
SQLALCHEMY_POOL_TIMEOUT = 30
SQLALCHEMY_POOL_RECYCLE = 3600
SQLALCHEMY_MAX_OVERFLOW = 10
SQLALCHEMY_ECHO = False

# Test connections before using them (prevents stale connection errors)
SQLALCHEMY_ENGINE_OPTIONS = {
    "pool_pre_ping": True,
}

# -----------------------------------------------------------------------------
# Application Settings
# -----------------------------------------------------------------------------

# Disable example data loading
SUPERSET_LOAD_EXAMPLES = False

# Query result limits
ROW_LIMIT = 50000
SAMPLES_ROW_LIMIT = 1000
VIZ_ROW_LIMIT = 10000

# Query timeout (seconds)
SUPERSET_WEBSERVER_TIMEOUT = 300

# -----------------------------------------------------------------------------
# Security Settings
# -----------------------------------------------------------------------------

# Enable CSRF protection
WTF_CSRF_ENABLED = True

# Session cookie settings
SESSION_COOKIE_SECURE = False  # Set to True when using HTTPS
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"

# Enable proxy fix if behind load balancer
# This allows Superset to correctly detect the client's IP and protocol
ENABLE_PROXY_FIX = True

# -----------------------------------------------------------------------------
# Feature Flags
# -----------------------------------------------------------------------------

FEATURE_FLAGS = {
    # Enable async queries (requires Celery/Redis setup)
    "GLOBAL_ASYNC_QUERIES": False,

    # Dashboard features
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "DASHBOARD_VIRTUALIZATION": True,

    # Enable alerts and reports (requires Celery setup)
    "ALERT_REPORTS": False,

    # Enable embedded dashboards
    "EMBEDDED_SUPERSET": False,
}

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------

# Log to stdout/stderr for CloudWatch Logs integration
ENABLE_FLASK_COMPRESS = True

# -----------------------------------------------------------------------------
# Optional: Data Source Configuration
# -----------------------------------------------------------------------------

# If you want to configure allowed file uploads
ALLOWED_EXTENSIONS = {"csv", "xlsx", "txt"}

# Maximum file upload size (bytes) - 100MB
MAX_CONTENT_LENGTH = 100 * 1024 * 1024

# -----------------------------------------------------------------------------
# Cache Configuration - Redis
# -----------------------------------------------------------------------------

# Redis configuration for production-ready caching
# Redis connection details are injected from environment variables via ECS
REDIS_HOST = os.environ.get("REDIS_HOST")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD")
REDIS_SSL = os.environ.get("REDIS_SSL", "true").lower() == "true"

# Build Redis URL
if REDIS_HOST:
    REDIS_PROTOCOL = "rediss" if REDIS_SSL else "redis"
    # Build URL with or without password
    if REDIS_PASSWORD:
        REDIS_URL = f"{REDIS_PROTOCOL}://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}/0"
    else:
        REDIS_URL = f"{REDIS_PROTOCOL}://{REDIS_HOST}:{REDIS_PORT}/0"

    # Filter state cache (required for dashboard filter state persistence)
    FILTER_STATE_CACHE_CONFIG = {
        "CACHE_TYPE": "RedisCache",
        "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours
        "CACHE_KEY_PREFIX": "superset_filter_",
        "CACHE_REDIS_URL": REDIS_URL,
    }

    # Explore form data cache (required for explore chart form data)
    EXPLORE_FORM_DATA_CACHE_CONFIG = {
        "CACHE_TYPE": "RedisCache",
        "CACHE_DEFAULT_TIMEOUT": 86400,  # 24 hours
        "CACHE_KEY_PREFIX": "superset_explore_",
        "CACHE_REDIS_URL": REDIS_URL,
    }

    # General cache (metadata, permissions, etc.)
    CACHE_CONFIG = {
        "CACHE_TYPE": "RedisCache",
        "CACHE_DEFAULT_TIMEOUT": 300,  # 5 minutes
        "CACHE_KEY_PREFIX": "superset_cache_",
        "CACHE_REDIS_URL": REDIS_URL,
    }

    # Data cache (query results)
    DATA_CACHE_CONFIG = {
        "CACHE_TYPE": "RedisCache",
        "CACHE_DEFAULT_TIMEOUT": 3600,  # 1 hour
        "CACHE_KEY_PREFIX": "superset_data_",
        "CACHE_REDIS_URL": REDIS_URL,
    }
else:
    # Fallback to SimpleCache if Redis not configured
    import logging
    logging.warning("Redis not configured. Using SimpleCache as fallback. This is not recommended for production.")

    CACHE_CONFIG = {
        "CACHE_TYPE": "SimpleCache",
        "CACHE_DEFAULT_TIMEOUT": 300,
    }

    DATA_CACHE_CONFIG = {
        "CACHE_TYPE": "SimpleCache",
        "CACHE_DEFAULT_TIMEOUT": 3600,
    }

# -----------------------------------------------------------------------------
# Development/Debug Settings (Override in production)
# -----------------------------------------------------------------------------

# These will be False in production
DEBUG = False
FLASK_ENV = "production"

# Optionally override based on environment
if os.environ.get("ENVIRONMENT") == "dev":
    DEBUG = False  # Keep False even in dev for security
    FLASK_ENV = "development"
