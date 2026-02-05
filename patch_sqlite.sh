#!/bin/sh
# Fix SQLite migration bug for FreeBSD
# FreeBSD SQLite treats double-quoted strings as column identifiers (per SQL standard)
# This script patches n8n migration files to use single quotes for string literals

MIGRATION_DIR="/usr/local/lib/node_modules/n8n/node_modules/@n8n/db/dist/migrations/sqlite"

if [ ! -d "$MIGRATION_DIR" ]; then
    echo "Migration directory not found: $MIGRATION_DIR"
    MIGRATION_DIR="/usr/local/lib/node_modules/n8n/packages/@n8n/db/dist/migrations/sqlite"
    if [ ! -d "$MIGRATION_DIR" ]; then
        echo "Alternate migration directory also not found"
        exit 0
    fi
fi

echo "Patching migration files in: $MIGRATION_DIR"

# Create a Perl script for cleaner processing
cat > /tmp/fix_sqlite_quotes.pl << 'PERLSCRIPT'
#!/usr/bin/perl -pi

# Fix WHERE NAME = "${tablePrefix}xxx" -> WHERE NAME = '${tablePrefix}xxx'
s/(WHERE\s+(?:NAME|name)\s*=\s*)"(\$\{tablePrefix\}[^"']+)"/$1'$2'/gi;

# Fix WHERE NAME = "${tablePrefix}xxx'; (mismatched quotes in original code)
s/(WHERE\s+(?:NAME|name)\s*=\s*)"(\$\{tablePrefix\}[^"']+)'/$1'$2'/gi;

# Fix known string literals that are incorrectly double-quoted
# These appear in INSERT VALUES, comparisons, etc.
# Pattern: "word" where word is a known string value (not a column reference)

# Role names and scopes
s/"(owner|member|user|editor)"/'$1'/g;
s/"(global|workflow|credential|project)"/'$1'/g;

# Boolean-like strings
s/"(true|false)"/'$1'/g;

# Fix VALUES ("xxx", "yyy") patterns - convert string literals
# But be careful not to break column references in CREATE TABLE
# Only fix when inside VALUES() context
s/(VALUES\s*\([^)]*)"([a-z_]+)"([^)]*\))/$1'$2'$3/gi;
PERLSCRIPT

chmod +x /tmp/fix_sqlite_quotes.pl

for f in "$MIGRATION_DIR"/*.js; do
    [ -f "$f" ] || continue
    echo "Processing: $(basename "$f")"
    perl /tmp/fix_sqlite_quotes.pl "$f"
done

rm -f /tmp/fix_sqlite_quotes.pl
echo "SQLite migration patching complete"
