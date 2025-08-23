-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'customer' -- 'customer' or 'vendor'
);

-- Enable Row Level Security (RLS) for the users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policy for authenticated users to view their own profile
CREATE POLICY "Users can view their own profile" ON users
FOR SELECT USING (auth.uid() = id);

-- Create policy for authenticated users to update their own profile
CREATE POLICY "Users can update their own profile" ON users
FOR UPDATE USING (auth.uid() = id);

-- Create policy for authenticated users to delete their own profile
CREATE POLICY "Users can delete their own profile" ON users
FOR DELETE USING (auth.uid() = id);

-- Create policy for new users to insert their own profile (after signup)
CREATE POLICY "New users can insert their own profile" ON users
FOR INSERT WITH CHECK (auth.uid() = id);