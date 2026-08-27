import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { config } from '../config.js';

const here = dirname(fileURLToPath(import.meta.url));

/**
 * Opens the database and applies the schema.
 *
 * `:memory:` is a real option here rather than a test-only hack — the whole
 * suite runs against a fresh in-memory database per test, which is why the
 * tests need no fixtures and cannot leak state into each other.
 */
export function openDatabase(file = config.databaseFile) {
  const db = new DatabaseSync(file);
  db.exec(readFileSync(join(here, 'schema.sql'), 'utf8'));
  return db;
}

/** ISO-8601 in UTC. Every timestamp in this codebase is written by the server. */
export const nowIso = () => new Date().toISOString();

/**
 * Runs `fn` inside a transaction and rolls back if it throws.
 *
 * node:sqlite is synchronous, so this is a plain try/catch — no await, no
 * chance of an interleaved statement landing inside the transaction.
 */
export function transaction(db, fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    try {
      db.exec('ROLLBACK');
    } catch {
      // The rollback failing is not the error worth reporting.
    }
    throw error;
  }
}
