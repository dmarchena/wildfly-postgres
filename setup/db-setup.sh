#!/bin/sh
set -e

if [ ! -d "$PGDATA" ]; then
    mkdir -p ${PGDATA}
fi
chown -R postgres:postgres "$PGDATA"

gosu postgres initdb
sed -ri "s/^#(listen_addresses\s*=\s*)\S+/\1'*'/" "$PGDATA"/postgresql.conf

: ${POSTGRES_USER:=$POSTGRES_USER}
: ${POSTGRES_DB:=$POSTGRES_DB}

if [ "$POSTGRES_PASSWORD" ]; then
  pass="PASSWORD '$POSTGRES_PASSWORD'"
  authMethod=md5
else
  echo "==============================="
  echo "!!! Use \$POSTGRES_PASSWORD env var to secure your database !!!"
  echo "==============================="
  pass=
  authMethod=trust
fi
echo

createSql="CREATE DATABASE $POSTGRES_DB;"
echo $createSql | gosu postgres postgres --single -jE
echo

op=CREATE

userSql="$op USER $POSTGRES_USER WITH SUPERUSER $pass;"
echo $userSql | gosu postgres postgres --single -jE
echo

# internal start of server in order to allow set-up using psql-client
# does not listen on TCP/IP and waits until start finishes
gosu postgres pg_ctl -D "$PGDATA" \
    -o "-c listen_addresses=''" \
    -w start
echo

cd /build.initdb.d/
for f in *; do
        case "$f" in
            *.sql) echo "$0: running $f"; psql --quiet --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --file="$f" &> /dev/null;;
            *)     echo "$0: ignoring $f" ;;
        esac
        echo
done
cd ../
sync

gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

{ echo; echo "host all all 0.0.0.0/0 $authMethod"; } >> "$PGDATA"/pg_hba.conf
sync