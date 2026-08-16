-- Migration: Seed departments table with core departments
-- Author: John Samula
BEGIN;

INSERT INTO public.departments (name, description) values
('Engineering', 'Build and maintain the product, infrastructure, and QA'),
('Product', 'Define product vision, roadmap, and requirements'),
('Design', 'UI/UX design and user research'),
('Sales', 'Find new customers and close deals'),
('Marketing', 'Generate leads, brand, and content'),
('Customer Success', 'Onboard customers and ensure retention'),
('Support', 'Handle tickets, bugs, and technical helpdesk'),
('HR', 'Hiring, people operations, and company culture'),
('Finance', 'Accounting, billing, and financial operations'),
('IT & Security', 'Manage devices, access, and company security')
ON CONFLICT (name) DO NOTHING;

COMMIT;