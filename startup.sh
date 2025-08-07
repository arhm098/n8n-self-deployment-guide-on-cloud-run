#!/bin/sh

# Map Cloud Run's PORT to N8N_PORT if it exists
if [ -n "$PORT" ]; then
  export N8N_PORT=$PORT
fi

# Print environment variables for debugging
echo "Database settings:"
echo "DB_TYPE: $DB_TYPE"
echo "DB_POSTGRESDB_HOST: $DB_POSTGRESDB_HOST"
echo "DB_POSTGRESDB_PORT: $DB_POSTGRESDB_PORT"
echo "N8N_PORT: $N8N_PORT"

# Start n8n with its original entrypoint
exec /docker-entrypoint.sh
