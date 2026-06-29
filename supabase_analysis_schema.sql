-- ============================================================
-- Call Analysis Schema
-- Run this in Supabase SQL Editor (once)
-- ============================================================

-- 1. Rules table — edit rows here to change flags without touching n8n
CREATE TABLE IF NOT EXISTS public.call_analysis_rules (
  id        serial PRIMARY KEY,
  rule_type text    NOT NULL, -- compliance_required | compliance_forbidden | sentiment_agent | outcome
  flag_name text    NOT NULL, -- machine-readable flag key
  keywords  text[]  NOT NULL, -- any match (case-insensitive) triggers the flag
  speaker   text,             -- 'A' = agent, 'B' = lead, NULL = either
  severity  text    NOT NULL DEFAULT 'medium', -- low | medium | high
  active    boolean NOT NULL DEFAULT true
);

-- Seed rules (generic — replace/add your real phrases via Supabase dashboard)
INSERT INTO public.call_analysis_rules (rule_type, flag_name, keywords, speaker, severity) VALUES
  -- Compliance: agent MUST say these things
  ('compliance_required', 'missed_disclosure_debt',      ARRAY['debt','settlement','enrolled'],                     'A', 'high'),
  ('compliance_required', 'missed_disclosure_recording', ARRAY['recorded','recording','monitored','consent'],        'A', 'high'),
  -- Compliance: agent must NOT say these things
  ('compliance_forbidden', 'agent_promised_results',     ARRAY['guarantee','guaranteed','promise you','I promise'],  'A', 'high'),
  ('compliance_forbidden', 'agent_aggressive',           ARRAY['shut up','listen to me','stop talking','you always'],'A', 'high'),
  -- Agent sentiment
  ('sentiment_agent', 'agent_rushed',                    ARRAY['anyway','moving on','next question','real quick'],   'A', 'low'),
  ('sentiment_agent', 'agent_dismissive',                ARRAY['as I said','like I said','already told you'],        'A', 'low'),
  -- Call outcome (lead / speaker B)
  ('outcome', 'lead_not_interested',                     ARRAY['not interested','remove me','do not call','stop calling','take me off'],'B', 'medium'),
  ('outcome', 'lead_callback_requested',                 ARRAY['call me back','call back later','better time','try again'],           'B', 'medium'),
  ('outcome', 'lead_strong_interest',                    ARRAY['sounds good','i want to','sign me up','let''s do it','yes let''s'],   'B', 'medium'),
  ('outcome', 'appointment_set',                         ARRAY['scheduled','appointment','booked','confirmed for','set you up'],      'A', 'medium')
ON CONFLICT DO NOTHING;

-- 2. New columns on the transcripts table
ALTER TABLE public.ytel_call_transcripts
  ADD COLUMN IF NOT EXISTS analysis_flags    jsonb,
  ADD COLUMN IF NOT EXISTS analysis_summary  jsonb,
  ADD COLUMN IF NOT EXISTS analyzed_at       timestamptz;

-- Computed convenience columns for dashboard filtering
ALTER TABLE public.ytel_call_transcripts
  ADD COLUMN IF NOT EXISTS has_compliance_issue boolean
    GENERATED ALWAYS AS (
      (analysis_summary IS NOT NULL)
      AND ((analysis_summary->>'compliance_pass')::boolean = false)
    ) STORED;

ALTER TABLE public.ytel_call_transcripts
  ADD COLUMN IF NOT EXISTS outcome_flag text
    GENERATED ALWAYS AS (analysis_summary->>'outcome') STORED;
