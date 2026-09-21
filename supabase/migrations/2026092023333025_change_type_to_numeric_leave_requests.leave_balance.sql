-- ============================================
-- Migration: leave_balance INT → NUMERIC(hours)
-- Rationale: support intraday leave via fractional days
-- Policy:   20 days × 8 hours = 160 hours default
-- Author: John Samula
-- ============================================

-- Change column type
ALTER TABLE public.profiles
  ALTER COLUMN leave_balance TYPE NUMERIC(6, 2)
  USING leave_balance::NUMERIC(6, 2);

-- Set new default (160 hours = 20 days)
ALTER TABLE public.profiles
  ALTER COLUMN leave_balance SET DEFAULT 160.00;

-- Convert existing "days" values to "hours"
UPDATE public.profiles
SET leave_balance = leave_balance * 8
WHERE leave_balance <= 30;

-- Any NULL balances → default
UPDATE public.profiles
SET leave_balance = 160.00
WHERE leave_balance IS NULL;

-- Add a check so balance can't go silly
ALTER TABLE public.profiles
  ADD CONSTRAINT leave_balance_non_negative
  CHECK (leave_balance >= 0);