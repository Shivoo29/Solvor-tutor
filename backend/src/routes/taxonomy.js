const { Router } = require('express');
const { query } = require('../db/connection');
const { authenticate } = require('../middleware/auth');

const router = Router();

// GET /taxonomy — full taxonomy tree
router.get('/', authenticate, async (req, res, next) => {
  try {
    const result = await query(
      'SELECT id, name, parent_id, level FROM taxonomy_nodes ORDER BY level, name'
    );

    const nodes = result.rows;
    const map = new Map();
    const roots = [];

    for (const node of nodes) {
      map.set(node.id, { ...node, children: [] });
    }

    for (const node of nodes) {
      const mapped = map.get(node.id);
      if (node.parent_id && map.has(node.parent_id)) {
        map.get(node.parent_id).children.push(mapped);
      } else {
        roots.push(mapped);
      }
    }

    res.json(roots);
  } catch (err) {
    next(err);
  }
});

module.exports = router;
