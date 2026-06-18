-- Solvor Tutor — Initial PostgreSQL Schema
-- All 6 tables required by PRD Section 4

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    selected_exam VARCHAR(50),
    ui_language VARCHAR(10) DEFAULT 'en',
    daily_capacity_minutes INTEGER DEFAULT 30,
    weak_domains JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_phone ON users(phone_number);

-- 2. taxonomy_nodes
CREATE TABLE IF NOT EXISTS taxonomy_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    parent_id UUID REFERENCES taxonomy_nodes(id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_taxonomy_parent ON taxonomy_nodes(parent_id);

-- 3. questions
CREATE TABLE IF NOT EXISTS questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    taxonomy_id UUID NOT NULL REFERENCES taxonomy_nodes(id),
    question_en TEXT NOT NULL,
    question_hi TEXT NOT NULL,
    options_en JSONB NOT NULL,
    options_hi JSONB NOT NULL,
    correct_option INTEGER NOT NULL,
    difficulty_level VARCHAR(20) NOT NULL DEFAULT 'medium',
    explanation_en TEXT NOT NULL,
    explanation_hi TEXT NOT NULL,
    explanation_hinglish TEXT NOT NULL DEFAULT '',
    shortcut_formula_note TEXT,
    common_mistake_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_questions_taxonomy ON questions(taxonomy_id);
CREATE INDEX idx_questions_difficulty ON questions(difficulty_level);

-- 4. tests
CREATE TABLE IF NOT EXISTS tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    test_type VARCHAR(50) NOT NULL,
    total_questions INTEGER NOT NULL,
    time_limit_minutes INTEGER NOT NULL DEFAULT 30,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tests_user ON tests(user_id);
CREATE INDEX idx_tests_completed ON tests(completed_at);

-- 5. test_question_mapping
CREATE TABLE IF NOT EXISTS test_question_mapping (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID NOT NULL REFERENCES tests(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id),
    sequence_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tqm_test ON test_question_mapping(test_id);
CREATE INDEX idx_tqm_question ON test_question_mapping(question_id);

-- 6. synchronization_ledger
CREATE TABLE IF NOT EXISTS synchronization_ledger (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    event_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    client_timestamp TIMESTAMPTZ NOT NULL,
    processed_status BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sync_user ON synchronization_ledger(user_id);
CREATE INDEX idx_sync_processed ON synchronization_ledger(processed_status);
CREATE INDEX idx_sync_client_ts ON synchronization_ledger(client_timestamp);
