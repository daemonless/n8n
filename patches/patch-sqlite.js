#!/usr/bin/env node
// Patch AbstractSqliteQueryRunner.addColumns to validate column names against
// PRAGMA table_info before calling recreateTable. Without this, TypeORM's
// metadata cache may include columns (e.g. pastExecutionId) that were never
// actually created in the SQLite table due to FK handling quirks, causing
// recreateTable to generate "SELECT "pastExecutionId" FROM ..." which fails
// on SQLite builds with DQS mode disabled (the default in modern SQLite).

const fs = require('fs');
const path = require('path');

// @n8n/typeorm can land nested under n8n/node_modules/ or hoisted to the
// parent node_modules/ depending on how n8n was installed -- check both
// instead of hardcoding one location.
const candidates = [
  '/usr/local/lib/node_modules/n8n/node_modules/@n8n/typeorm',
  '/usr/local/lib/node_modules/@n8n/typeorm',
];
const pkgDir = candidates.find((p) => fs.existsSync(p));
if (!pkgDir) {
  console.error('patch-sqlite.js: @n8n/typeorm not found in any known location');
  process.exit(1);
}
const target = path.join(
  pkgDir,
  'driver/sqlite-abstract/AbstractSqliteQueryRunner.js'
);

const src = fs.readFileSync(target, 'utf8');

const from = [
  'const changedTable = table.clone();',
  '        columns.forEach((column) => changedTable.addColumn(column));',
  '        await this.recreateTable(changedTable, table);',
].join('\n');

const to = [
  'const changedTable = table.clone();',
  '        // daemonless patch: validate against actual DB columns before recreateTable',
  '        // to handle TypeORM metadata cache containing columns never created in SQLite',
  '        const [, _tbl] = this.splitTablePath(table.name);',
  '        const _rows = await this.query(`PRAGMA table_info(${_tbl})`);',
  '        const _actual = new Set(_rows.map(r => r.name));',
  '        changedTable.columns = changedTable.columns.filter(c => _actual.has(c.name));',
  '        changedTable.foreignKeys = changedTable.foreignKeys.filter(fk => fk.columnNames.every(n => _actual.has(n)));',
  '        table.columns = table.columns.filter(c => _actual.has(c.name));',
  '        table.foreignKeys = table.foreignKeys.filter(fk => fk.columnNames.every(n => _actual.has(n)));',
  '        // end daemonless patch',
  '        columns.forEach((column) => changedTable.addColumn(column));',
  '        await this.recreateTable(changedTable, table);',
].join('\n');

if (!src.includes(from)) {
  console.error('patch-sqlite.js: target string not found — patch may already be applied or upstream changed');
  process.exit(1);
}

fs.writeFileSync(target, src.replace(from, to));
console.log('patch-sqlite.js: patched AbstractSqliteQueryRunner.addColumns');
