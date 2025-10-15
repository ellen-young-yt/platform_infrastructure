# Superset Production Dockerfile
# Based on Apache Superset official recommendations:
# https://superset.apache.org/docs/installation/docker-builds/

FROM apache/superset:5.0.0

# Switch to root to install dependencies
USER root

# Install PostgreSQL driver and Redis client using uv directly
# PATH is already set to include /app/.venv/bin by the base image
RUN . /app/.venv/bin/activate && \
    uv pip install \
    psycopg2-binary==2.9.9 \
    snowflake-sqlalchemy==1.7.7 \
    redis==5.0.1
# Copy custom configuration file
COPY --chown=superset superset_config.py /app/
ENV SUPERSET_CONFIG_PATH=/app/superset_config.py

# Switch back to superset user for security
USER superset

# Use the default entrypoint from the base image
# This will be overridden by the ECS task definition command
