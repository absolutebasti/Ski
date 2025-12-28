-- Ski Tracker - Supabase Database Schema
-- Run this in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Runs table - stores all ski runs
CREATE TABLE runs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    resort VARCHAR(50) DEFAULT 'kitzbuehel',
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration INTEGER, -- milliseconds
    distance DECIMAL(10, 3), -- kilometers
    max_speed DECIMAL(6, 2), -- km/h
    avg_speed DECIMAL(6, 2), -- km/h
    vertical_drop INTEGER, -- meters
    start_altitude INTEGER, -- meters
    end_altitude INTEGER, -- meters
    positions JSONB, -- array of GPS positions
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE runs ENABLE ROW LEVEL SECURITY;

-- Users can only see their own runs
CREATE POLICY "Users can view own runs" ON runs
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own runs" ON runs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own runs" ON runs
    FOR DELETE USING (auth.uid() = user_id);

-- Slope status table - stores scraped slope data
CREATE TABLE slope_status (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    resort VARCHAR(50) NOT NULL,
    slopes_open INTEGER DEFAULT 0,
    slopes_total INTEGER DEFAULT 0,
    lifts_open INTEGER DEFAULT 0,
    lifts_total INTEGER DEFAULT 0,
    slopes JSONB, -- detailed slope status
    lifts JSONB, -- detailed lift status
    source_url TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Allow anyone to read slope status
ALTER TABLE slope_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view slope status" ON slope_status
    FOR SELECT USING (true);

-- Only service role can update slope status (for scraper)
CREATE POLICY "Service role can update slope status" ON slope_status
    FOR ALL USING (auth.role() = 'service_role');

-- Personal records view (computed from runs)
CREATE VIEW user_records AS
SELECT 
    user_id,
    MAX(max_speed) as top_speed,
    MAX(distance) as longest_run,
    MAX(vertical_drop) as most_vertical,
    COUNT(*) as total_runs,
    SUM(distance) as total_distance,
    SUM(vertical_drop) as total_vertical,
    SUM(duration) as total_time
FROM runs
GROUP BY user_id;

-- Index for faster queries
CREATE INDEX idx_runs_user_id ON runs(user_id);
CREATE INDEX idx_runs_start_time ON runs(start_time DESC);
CREATE INDEX idx_slope_status_resort ON slope_status(resort);
CREATE INDEX idx_slope_status_updated ON slope_status(updated_at DESC);

-- Function to update slope status (called by Edge Function)
CREATE OR REPLACE FUNCTION update_slope_status(
    p_resort VARCHAR,
    p_slopes_open INTEGER,
    p_slopes_total INTEGER,
    p_lifts_open INTEGER,
    p_lifts_total INTEGER,
    p_slopes JSONB,
    p_lifts JSONB,
    p_source_url TEXT
)
RETURNS UUID AS $$
DECLARE
    result_id UUID;
BEGIN
    INSERT INTO slope_status (resort, slopes_open, slopes_total, lifts_open, lifts_total, slopes, lifts, source_url, updated_at)
    VALUES (p_resort, p_slopes_open, p_slopes_total, p_lifts_open, p_lifts_total, p_slopes, p_lifts, p_source_url, NOW())
    RETURNING id INTO result_id;
    
    RETURN result_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

