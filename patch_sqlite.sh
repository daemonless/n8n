#!/bin/sh
# Fix SQLite migration bug for FreeBSD
# FreeBSD SQLite treats double-quoted strings as column identifiers
# This script patches n8n migration files to use single quotes for string literals

MIGRATION_DIR="/usr/local/lib/node_modules/n8n/node_modules/@n8n/db/dist/migrations/sqlite"

if [ ! -d "$MIGRATION_DIR" ]; then
    echo "Migration directory not found: $MIGRATION_DIR"
    exit 0
fi

for f in "$MIGRATION_DIR"/*.js; do
    # 1. Fix table name references in WHERE clauses (SQLITE_MASTER checks)
    # The file has: WHERE NAME = "${tablePrefix}execution_entity"
    # We want:      WHERE NAME = '${tablePrefix}execution_entity'
    # We use perl for safer regex handling to avoid sed escaping issues
    perl -pi -e 's/WHERE NAME = "\\\${tablePrefix}([^\\\"]+)"/WHERE NAME = '\\\'${tablePrefix}\\1'/g' "$f"

    # 2. Fix literal values that are incorrectly double-quoted
    for word in global workflow credential project owner member user editor true false; do
        # Replace "word" with 'word' globally
        perl -pi -e "s/\"$word\"/'$word'/g" "$f"
    done
done