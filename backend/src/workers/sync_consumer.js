require('dotenv').config({ path: require('path').join(__dirname, '..', '..', '.env') });
const { query } = require('../db/connection');

async function processTestSubmit(payload) {
  const { testId, userId, answers, startedAt, completedAt } = payload;

  const testResult = await query('SELECT id FROM tests WHERE id = $1', [testId]);
  if (testResult.rows.length === 0) {
    const userResult = await query('SELECT id FROM users WHERE id = $1', [userId]);
    if (userResult.rows.length === 0) return;

    await query(
      `INSERT INTO tests (id, user_id, test_type, total_questions, time_limit_minutes, started_at, completed_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [testId, userId, 'practice', answers.length, 30, startedAt, completedAt]
    );
  } else {
    await query(
      `UPDATE tests SET completed_at = $1 WHERE id = $2 AND (completed_at IS NULL OR $1 > completed_at)`,
      [completedAt, testId]
    );
  }
}

async function processBookmarkAdd(payload) {
}

async function processProfileUpdate(payload) {
  const { userId, updates } = payload;

  const fields = [];
  const values = [];
  let idx = 1;

  for (const [key, value] of Object.entries(updates)) {
    const columnMap = {
      selectedExam: 'selected_exam',
      uiLanguage: 'ui_language',
      dailyCapacityMinutes: 'daily_capacity_minutes',
      weakDomains: 'weak_domains',
    };

    const col = columnMap[key];
    if (!col) continue;

    fields.push(`${col} = $${idx++}`);
    if (col === 'weak_domains') {
      values.push(JSON.stringify(value));
    } else {
      values.push(value);
    }
  }

  if (fields.length === 0) return;

  values.push(userId);
  await query(
    `UPDATE users SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${idx}`,
    values
  );
}

const eventHandlers = {
  TEST_SUBMIT: processTestSubmit,
  BOOKMARK_ADD: processBookmarkAdd,
  PROFILE_UPDATE: processProfileUpdate,
};

async function processEvent(event) {
  const handler = eventHandlers[event.event_type];
  if (!handler) {
    console.warn(`Unknown event type: ${event.event_type}`);
    return;
  }

  const payload = typeof event.payload === 'string' ? JSON.parse(event.payload) : event.payload;

  await handler(payload);
}

async function markProcessed(eventId) {
  await query(
    'UPDATE synchronization_ledger SET processed_status = TRUE WHERE id = $1',
    [eventId]
  );
}

async function pollAndProcess() {
  try {
    const result = await query(
      `SELECT * FROM synchronization_ledger
       WHERE processed_status = FALSE
       ORDER BY client_timestamp ASC
       LIMIT 50
       FOR UPDATE SKIP LOCKED`
    );

    for (const event of result.rows) {
      try {
        await processEvent(event);
        await markProcessed(event.id);
      } catch (err) {
        console.error(`Failed to process event ${event.id}:`, err.message);
      }
    }
  } catch (err) {
    console.error('Poll cycle error:', err.message);
  }
}

const POLL_INTERVAL_MS = 5000;
let intervalHandle;

function start() {
  console.log('Sync consumer started — polling every %dms', POLL_INTERVAL_MS);
  intervalHandle = setInterval(pollAndProcess, POLL_INTERVAL_MS);
}

function stop() {
  if (intervalHandle) {
    clearInterval(intervalHandle);
    intervalHandle = null;
  }
}

if (require.main === module) {
  start();
}

module.exports = { start, stop, pollAndProcess };
