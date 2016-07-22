#!/bin/bash

# Adapted from https://raw.githubusercontent.com/hypriot/rpi-mysql/42d571c63e0da4ff8da5e1a70dc53e53ffc59fad/entrypoint.sh
set -e

if [ "${1:0:1}" = '-' ]; then
    set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
    # read DATADIR from the MySQL config
    DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
    
    if [ ! -d "$DATADIR/mysql" ]; then
        if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
            echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
            echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
            exit 1
        fi
        
        echo 'Initializing database'
        mysql_install_db --datadir="$DATADIR"
        echo 'Database initialized'
        
        # These statements _must_ be on individual lines, and _must_ end with
        # semicolons (no line breaks or comments are permitted).
        # TODO proper SQL escaping on ALL the things D:
        
        tempSqlFile='/tmp/mysql-first-time.sql'
        (
        echo "DELETE FROM mysql.user ;"
        echo "CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;"
        echo "GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;"
        echo "DROP DATABASE IF EXISTS test ;"
        ) >> "$tempSqlFile"
        
        if [ "$KODI_DB_USER" -a "$KODI_DB_PASSWORD" ]; then
            echo "CREATE USER '$KODI_DB_USER' IDENTIFIED BY '$KODI_DB_PASSWORD' ;" >> "$tempSqlFile"

            echo "GRANT ALL ON *.* TO '$KODI_DB_USER' ;" >> "$tempSqlFile"
        fi
        
        echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
        
        set -- "$@" --init-file="$tempSqlFile"
    fi
    
    chown -R mysql:mysql "$DATADIR"
fi

exec "$@"
