require('dotenv').config();

const express = require('express');
const cors = require('cors');
const { errorHandler } = require('./src/middleware/errorHandler');

const authRoutes = require('./src/routes/auth');
const questionsRoutes = require('./src/routes/questions');
const taxonomyRoutes = require('./src/routes/taxonomy');
const syncRoutes = require('./src/routes/sync');
const scheduleRoutes = require('./src/routes/schedule');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/auth', authRoutes);
app.use('/questions', questionsRoutes);
app.use('/taxonomy', taxonomyRoutes);
app.use('/sync', syncRoutes);
app.use('/schedule', scheduleRoutes);

app.use(errorHandler);

if (process.env.NODE_ENV !== 'test') {
  app.listen(PORT, () => {
    console.log(`Solvor Tutor API listening on port ${PORT}`);
  });
}

module.exports = app;
