-- Migration: change column data type to timestamptz in the leave_requests table
-- Author: John Samula

--convert start_date
ALTER TABLE leave_requests
ALTER COLUMN start_date TYPE timestamptz
USING start_date::timestamptz;

-- convert end_date
ALTER TABLE leave_requests
ALTER COLUMN end_date TYPE timestamptz
USING end_date::timestamptz;
