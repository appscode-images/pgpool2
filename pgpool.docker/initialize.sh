#!/bin/sh -e

(
  if [ -d "/init-scripts" ]; then
      echo "INIT: Init Directory Exists"
      # Wait for Pgpool-II to be ready
      CONFIG_FILE=${CONFIG_FILE:-"/config/pgpool.conf"}
      PGPOOL_HOST=${PGPOOL_HOST:-"localhost"}
      PGPOOL_PORT=${PGPOOL_PORT:-"9999"}
      PGPOOL_DBNAME=${PGPOOL_DBNAME:-"postgres"}

      # Extract SSL setting from pgpool.conf
      if [ -f "$CONFIG_FILE" ]; then
          SSL_ENABLED=$(grep -i "^ssl[[:space:]]*=" "$CONFIG_FILE" | awk -F '= *' '{print $2}' || echo "off")
      else
          echo "INIT: Error: $CONFIG_FILE not found"
          exit 1
      fi

      SSL_ENABLED=$(grep -E "^ssl\s*=" ${PGPOOL_INSTALL_DIR}/etc/pgpool.conf | tail -1 | awk -F '= *' '{print $2}' | tr -d "'")
      # Map Pgpool-II SSL setting to PGSSLMODE
      if [ "$SSL_ENABLED" = "on" ]; then
          SSLMODE="require"
      else
          SSLMODE="disable"
      fi

      # Retrieve username and password from secrets (adjust paths as needed)
      PASSWORD="${POSTGRES_PASSWORD:-}"
      USERNAME="${POSTGRES_USERNAME:-}"


      # Build pg_isready connection string
      args="host=$PGPOOL_HOST port=$PGPOOL_PORT user=$USERNAME password=$PASSWORD dbname=$PGPOOL_DBNAME"
      # Wait for Pgpool-II to be ready
      until pg_isready -d "$args"; do
          echo "INIT: Waiting for Pgpool-II to be ready..."
          sleep 2
      done
      echo "INIT: Pgpool-II is ready!"

      # Run initialization scripts
      cd /init-scripts || true
      for file in /init-scripts/*
      do
          case "$file" in
              *.sh)
                  echo "INIT: Running user provided initialization shell script $file"
                  sh "$file"
                  ;;
              *.lua)
                  echo "INIT: Running user provided initialization lua script $file"
                  # Adjust for Pgpool-II if needed (e.g., PCP commands or psql)
                  ;;
          esac
      done
  fi
) & /opt/pgpool-II/bin/start.sh