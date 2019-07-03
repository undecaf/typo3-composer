#!/bin/bash

# Runs t3 with the specified arguments and echoes the command line to stdout.
t3() {
    set -x
    ./t3 $@
    { set +x; } 2>/dev/null
}

# Echoes to stdout the number of containers whose names match the specified RE.
count_containers() {
    docker container ls --filter name='^/'"$1"'$' --format='{{.Names}}' | wc -l
}

# Echoes to stdout the number of volumes whose names match the specified RE.
count_volumes() {
    docker volume ls --filter name='^'"$1"'$' --format='{{.Name}}' | wc -l
}


echo $'\n********************* Testing'

source .travis/tags

set -e

# Will stop any configuration
trap './t3 stop --rm; docker volume rm typo3-root typo3-data & >/dev/null' EXIT

# Run tests only for the first tag since all images tagged in this build are identical
for T in $TAGS; do
    # TYPO3 standalone
    t3 run -t $T

    test $(count_containers 'typo3') -eq 1
    test $(count_containers 'typo3-db') -eq 0
    test $(count_volumes 'typo3-root') -eq 1
    test $(count_volumes 'typo3-data') -eq 0

    t3 stop --rm

    test $(count_containers 'typo3(-db)?') -eq 0
    test $(count_volumes 'typo3-root') -eq 1

    docker volume rm typo3-root >/dev/null

    # TYPO3 + MariaDB/PostgreSQL
    for DB_TYPE in mariadb postgresql; do
        t3 run -d $DB_TYPE -t $T

        test $(count_containers 'typo3(-db)?') -eq 2
        test $(count_volumes 'typo3-(root|data)') -eq 2

        t3 stop --rm

        test $(count_containers 'typo3(-db)?') -eq 0
        test $(count_volumes 'typo3-(root|data)') -eq 2

        docker volume rm typo3-root typo3-data >/dev/null
    done
done
