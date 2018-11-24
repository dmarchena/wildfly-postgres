#!/bin/sh

set -e

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Restoring $PGDATA ..."
    tar -xf /zdata/backup.tar -C $PGDATA
    #chown -R postgres:postgres "$PGDATA"
    sync
    echo "Done."
else
    echo "$PGDATA was already there, skipping restore."
fi


# echo "Launching command: $@ ..."
# if [ "$1" = 'postgres' ]; then
#     gosu postgres "$@"
# else
#     exec "$@"
# fi
gosu postgres postgres &

if [ -f "build.xml" ]; then
    gosu root ant
fi


exec $JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 -bmanagement=0.0.0.0
