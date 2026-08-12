-- Migration: Initial schema for JSKN Staff
-- Author: John samula
-- Description: departments table independent, profiles depends on auth.users table, leave_requests table depends on profiles.

-- Departments
CREATE TABLE public.departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- profiles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  department_id UUID REFERENCES departments(id),
  name TEXT NOT NULL,
  role TEXT NOT NULL CONSTRAINT profiles_role_check CHECK (role IN ('intern', 'employee', 'manager', 'contractor', 'hr_admin')) DEFAULT 'employee',
  job_title TEXT,
  phone TEXT,
  photo_url TEXT,
  avatar_version INT NOT NULL DEFAULT 1,
  leave_balance INT DEFAULT 10,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Leave Requests
CREATE TABLE public.leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  manager_id UUID REFERENCES profiles(id),
  reason TEXT,
  leave_type TEXT NOT NULL CONSTRAINT leave_type_check CHECK (leave_type IN ('Annual', 'Sick', 'Other')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  leave_status TEXT DEFAULT 'pending' CONSTRAINT leave_status_check CHECK (leave_status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Company Updates
CREATE TABLE public.company_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- HELPER FUNCTIONS: Bypass RLS to avoid recuursion
CREATE OR REPLACE FUNCTION public.user_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role from profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.user_department_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT department_id from profiles WHERE id = auth.uid();
$$;

-- Enable RLS
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.company_updates ENABLE ROW LEVEL SECURITY;

-- RLS POlICIES
-- Departments
CREATE POLICY "All staff members read" ON public.departments FOR SELECT USING(true);
CREATE POLICY "HR manage departments" ON public.departments FOR ALL USING (public.user_role() = 'hr_admin') WITH CHECK (public.user_role() = 'hr_admin');

-- Profiles
-- Employees: Can read, update, delete their own row
CREATE POLICY "Members own profile" ON public.profiles FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

--Managers: Can read, write peofiles in their department
CREATE POLICY "Managers their department" ON public.profiles FOR ALL USING (public.user_role() = 'manager' AND department_id = public.user_department_id()) WITH CHECK (public.user_role() = 'manager' AND department_id = public.user_department_id());

-- HR: Can do everything
CREATE POLICY "HR all" ON public.profiles FOR ALL USING (
  public.user_role() = 'hr_admin'
) WITH CHECK (
  public.user_role() = 'hr_admin'
);

-- Leave Requests
-- Employees: can add, read, update and delete their own row
CREATE POLICY "Employee own leave" ON public.leave_requests FOR ALL USING (auth.uid() = employee_id) WITH CHECK (auth.uid() = employee_id);

-- Manager: manage leaves in their department
CREATE POLICY "Manager dept leave" ON public.leave_requests FOR ALL USING (
  EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'manager'
    AND department_id = (SELECT department_id FROM profiles WHERE id = leave_requests.employee_id)
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
    AND p.role = 'manager'
    AND department_id = (SELECT department_id FROM profiles WHERE id = leave_requests.employee_id)
  )
);

-- HR: can do everything
CREATE POLICY "HR all leaves" ON public.leave_requests FOR ALL USING (
  public.user_role() = 'hr_admin'
) WITH CHECK (
  public.user_role() = 'hr_admin'
);

-- company_updates
CREATE POLICY "All staff read" ON public.company_updates FOR SELECT USING (true);

-- HR: Manages all
CREATE POLICY "HR on all" ON public.company_updates FOR ALL USING (
  public.user_role() = 'hr_admin'
) WITH CHECK (
  public.user_role() = 'hr_admin'
);

-- Function and Trigger to auto create a profile row
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
  BEGIN
    INSERT INTO public.profiles (
      id,
      department_id,
      name,
      role,
      job_title,
      phone,
      photo_url
    ) VALUES (
      NEW.id,
      (NEW.raw_user_meta_data->>'department_id')::UUID,
      COALESCE(NEW.raw_user_meta_data->>'name', 'New Employee'),
      COALESCE(NEW.raw_user_meta_data->>'role', 'employee'),
      NEW.raw_user_meta_data->>'job_title',
      NEW.raw_user_meta_data->>'phone',
      COALESCE(NEW.raw_user_meta_data->>'photo_url', 'https://cijjirlhmcwyozuntykc.supabase.co/storage/v1/object/public/jskn/jskn.png')
    );
    RETURN NEW;
  END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Bump avatar_version (called from client)
CREATE OR REPLACE FUNCTION public.bump_avatar_version()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
  DECLARE
    new_version INT;
  BEGIN
    UPDATE public.profiles
    SET avatar_version = avatar_version + 1
    WHERE id = auth.uid()
    RETURNING avatar_version INTO new_version;
    RETURN new_version;
  END;
$$;

-- Storage setup
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true), ('leave-docs', 'leave-docs', false)
ON CONFLICT (id) DO NOTHING;