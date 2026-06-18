const { Router } = require('express');
const { query } = require('../db/connection');
const { authenticate } = require('../middleware/auth');

const router = Router();

// POST /sync/push — receive sync_ledger events from device
router.post('/push', authenticate, async (req, res, next) => {
  try {
    const { events } = req.body;

    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'events array is required' });
    }

    // Sort by client_timestamp ascending (monotonic)
    events.sort((a, b) => new Date(a.clientTimestamp) - new Date(b.clientTimestamp));

    const results = [];

    for (const event of events) {
      const {
        id,
        eventType,
        payload,
        clientTimestamp,
      } = event;

      const inserted = await query(
        `INSERT INTO synchronization_ledger (id, user_id, event_type, payload, client_timestamp)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (id) DO UPDATE
           SET payload = EXCLUDED.payload,
               client_timestamp = EXCLUDED.client_timestamp
         RETURNING id`,
        [id, req.userId, eventType, JSON.stringify(payload), clientTimestamp]
      );

      results.push({ id: inserted.rows[0].id, status: 'accepted' });
    }

    res.json({ processed: results.length, events: results });
  } catch (err) {
    next(err);
  }
});

// GET /sync/pull?since=<ISO timestamp> — return updates since timestamp
router.get('/pull', authenticate, async (req, res, next) => {
  try {
    const { since } = req.query;

    if (!since) {
      return res.status(400).json({ error: 'since query param (ISO timestamp) is required' });
    }

    const result = await query(
      `SELECT id, user_id, event_type, payload, client_timestamp, processed_status, created_at
       FROM synchronization_ledger
       WHERE user_id = $1 AND client_timestamp > $2
       ORDER BY client_timestamp ASC`,
      [req.userId, since]
    );

    res.json({ events: result.rows });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
