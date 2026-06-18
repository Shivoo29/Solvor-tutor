const { Router } = require('express');
const { query } = require('../db/connection');
const { authenticate } = require('../middleware/auth');

const router = Router();

// GET /questions?exam=SSC&page=1&limit=20
router.get('/', authenticate, async (req, res, next) => {
  try {
    const { exam, page = '1', limit = '20' } = req.query;
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const offset = (pageNum - 1) * limitNum;

    let baseQuery = `
      SELECT q.id, q.question_en, q.question_hi, q.options_en, q.options_hi,
             q.correct_option, q.difficulty_level, q.explanation_en, q.explanation_hi,
             q.explanation_hinglish, q.shortcut_formula_note, q.common_mistake_note
      FROM questions q
    `;
    let countQuery = 'SELECT COUNT(*) AS total FROM questions q';
    const params = [];
    const conditions = [];

    if (exam) {
      conditions.push(`q.taxonomy_id IN (
        SELECT id FROM taxonomy_nodes
        WHERE parent_id IN (SELECT id FROM taxonomy_nodes WHERE name = $1)
      )`);
      params.push(exam);
    }

    if (conditions.length > 0) {
      const where = ' WHERE ' + conditions.join(' AND ');
      baseQuery += where;
      countQuery += where;
    }

    baseQuery += ' ORDER BY q.created_at DESC LIMIT $' + (params.length + 1) + ' OFFSET $' + (params.length + 2);

    const countParams = [...params];
    params.push(limitNum, offset);

    const [dataResult, countResult] = await Promise.all([
      query(baseQuery, params),
      query(countQuery, countParams),
    ]);

    res.json({
      questions: dataResult.rows,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: parseInt(countResult.rows[0].total, 10),
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
