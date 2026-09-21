-- ============================================
-- Trigger: Deduct leave balance on approval
-- Runs atomically with the status UPDATE
-- Author: John Samula 
-- ============================================

CREATE OR REPLACE FUNCTION public.deduct_leave_balance()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  hours_requested NUMERIC;
BEGIN
  -- Only fire when status becomes 'approved' (from anything else)
  IF NEW.leave_status = 'approved'
     AND OLD.leave_status IS DISTINCT FROM 'approved' THEN

    -- Total hours = (end − start) in seconds ÷ 3600
    hours_requested :=
      ROUND(
        EXTRACT(EPOCH FROM (NEW.end_date - NEW.start_date)) / 3600.0,
        2
      );

    -- Deduct, never below zero
    UPDATE public.profiles
    SET leave_balance = GREATEST(leave_balance - hours_requested, 0)
    WHERE id = NEW.employee_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_leave_approved ON public.leave_requests;

CREATE TRIGGER on_leave_approved
AFTER UPDATE ON public.leave_requests
FOR EACH ROW
WHEN (OLD.leave_status IS DISTINCT FROM NEW.leave_status)
EXECUTE FUNCTION public.deduct_leave_balance();