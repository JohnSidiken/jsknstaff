-- Migration: Add column (description) to public.departments
-- Author: John Samula
ALTER TABLE public.departments ADD COLUMN description TEXT;