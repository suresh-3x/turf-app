-- Create services table
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vendor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    location TEXT NOT NULL
);

-- Enable Row Level Security (RLS) for the services table
ALTER TABLE services ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view all services
CREATE POLICY "Allow authenticated users to view services" ON services
FOR SELECT USING (auth.role() = 'authenticated');

-- Allow vendors to insert their own services
CREATE POLICY "Allow vendors to insert their own services" ON services
FOR INSERT WITH CHECK (auth.uid() = vendor_id AND auth.role() = 'vendor');

-- Allow vendors to update their own services
CREATE POLICY "Allow vendors to update their own services" ON services
FOR UPDATE USING (auth.uid() = vendor_id AND auth.role() = 'vendor');

-- Allow vendors to delete their own services
CREATE POLICY "Allow vendors to delete their own services" ON services
FOR DELETE USING (auth.uid() = vendor_id AND auth.role() = 'vendor');