function errorHandler(err, req, res, _next) {
  console.error('Unhandled error:', err);

  if (err.code === '23505') {
    return res.status(409).json({ error: 'Duplicate resource' });
  }

  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referenced resource not found' });
  }

  const status = err.status || 500;
  const message = err.expose ? err.message : 'Internal server error';

  res.status(status).json({ error: message });
}

module.exports = { errorHandler };
