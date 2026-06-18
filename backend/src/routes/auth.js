const { Router } = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../db/connection');

const router = Router();

// In-memory OTP store — acceptable for MVP; replace with Redis in production
const otpStore = new Map();

function generateOtp() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// POST /auth/register — create user, send OTP
router.post('/register', async (req, res, next) => {
  try {
    const { phoneNumber, selectedExam, uiLanguage } = req.body;

    if (!phoneNumber) {
      return res.status(400).json({ error: 'phoneNumber is required' });
    }

    const existing = await query('SELECT id FROM users WHERE phone_number = $1', [phoneNumber]);
    let userId;

    if (existing.rows.length === 0) {
      const result = await query(
        `INSERT INTO users (id, phone_number, selected_exam, ui_language)
         VALUES ($1, $2, $3, $4)
         RETURNING id`,
        [uuidv4(), phoneNumber, selectedExam || null, uiLanguage || 'en']
      );
      userId = result.rows[0].id;
    } else {
      userId = existing.rows[0].id;
    }

    const otp = generateOtp();
    otpStore.set(phoneNumber, { otp, expiresAt: Date.now() + 5 * 60 * 1000 });

    console.log(`[OTP] ${phoneNumber} -> ${otp}`);

    res.json({ message: 'OTP sent', userId, otp });
  } catch (err) {
    next(err);
  }
});

// POST /auth/verify-otp — verify OTP, return JWT
router.post('/verify-otp', async (req, res, next) => {
  try {
    const { phoneNumber, otp } = req.body;

    if (!phoneNumber || !otp) {
      return res.status(400).json({ error: 'phoneNumber and otp are required' });
    }

    const entry = otpStore.get(phoneNumber);
    if (!entry) {
      return res.status(400).json({ error: 'No OTP sent for this number' });
    }

    if (Date.now() > entry.expiresAt) {
      otpStore.delete(phoneNumber);
      return res.status(400).json({ error: 'OTP expired' });
    }

    if (entry.otp !== otp) {
      return res.status(401).json({ error: 'Invalid OTP' });
    }

    otpStore.delete(phoneNumber);

    const result = await query('SELECT id FROM users WHERE phone_number = $1', [phoneNumber]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];
    const token = jwt.sign(
      { userId: user.id, phone: phoneNumber },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    res.json({ token, userId: user.id });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
