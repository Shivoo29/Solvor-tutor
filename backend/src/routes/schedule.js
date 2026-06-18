const { Router } = require('express');
const { query } = require('../db/connection');
const { authenticate } = require('../middleware/auth');

const router = Router();

// GET /schedule/:userId — return today's AI-generated study schedule
router.get('/:userId', authenticate, async (req, res, next) => {
  try {
    const { userId } = req.params;

    if (userId !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const userResult = await query(
      'SELECT id, selected_exam, daily_capacity_minutes, weak_domains FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];
    const weakDomains = user.weak_domains || [];

    let questions = [];
    if (weakDomains.length > 0) {
      const questionsResult = await query(
        `SELECT q.id, q.question_en, q.taxonomy_id, tn.name AS topic_name
         FROM questions q
         JOIN taxonomy_nodes tn ON tn.id = q.taxonomy_id
         WHERE tn.name = ANY($1::text[])
         ORDER BY RANDOM()
         LIMIT $2`,
        [weakDomains, user.daily_capacity_minutes]
      );
      questions = questionsResult.rows;
    }

    res.json({
      userId: user.id,
      date: new Date().toISOString().slice(0, 10),
      dailyCapacityMinutes: user.daily_capacity_minutes,
      weakDomains,
      suggestedQuestions: questions,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
