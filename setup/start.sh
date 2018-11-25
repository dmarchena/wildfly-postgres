#!/bin/sh

set -e


# echo "Launching command: $@ ..."
# if [ "$1" = 'postgres' ]; then
#     gosu postgres "$@"
# else
#     exec "$@"
# fi
exec gosu postgres postgres &

exec $JBOSS_HOME/bin/standalone.sh -b 0.0.0.0 -bmanagement=0.0.0.0 &

case $1 in
    ant)
        echo "Running ant..."
        if [ -f "/opt/workspace/build.xml" ]; then
            cd /opt/workspace
            gosu root ant
        fi
        ;;
    *)
        exec "$@"
esac

cd /entrypoint.after.d/
for f in *; do
    case "$f" in
        *.sh)  
            if [ -x "$f" ]; then
                echo "$0: running $f"
                "./$f"
            else
                echo "$0: sourcing $f"
                . "$f"
            fi
            ;;
        *)
            echo "$0: ignoring $f" 
            ;;
    esac
    echo
done

