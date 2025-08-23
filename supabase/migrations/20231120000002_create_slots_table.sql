-- Create slots table
CREATE TABLE slots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    service_id UUID REFERENCES services(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_booked BOOLEAN DEFAULT FALSE
);

-- Enable Row Level Security (RLS) for the slots table
ALTER TABLE slots ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view all slots
CREATE POLICY "Allow authenticated users to view slots" ON slots
FOR SELECT USING (auth.role() = 'authenticated');

-- Allow vendors to insert their own slots for their services
CREATE POLICY "Allow vendors to insert their own slots" ON slots
FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM services WHERE id = service_id AND vendor_id = auth.uid()) AND auth.role() = 'vendor');

-- Allow vendors to update their own slots for their services
CREATE POLICY "Allow vendors to update their own slots" ON slots
FOR UPDATE USING (EXISTS (SELECT 1 FROM services WHERE id = service_id AND vendor_id = auth.uid()) AND auth.role() = 'vendor');

-- Allow vendors to delete their own slots for their services
CREATE POLICY "Allow vendors to delete their own slots" ON slots
FOR DELETE USING (EXISTS (SELECT 1 FROM services WHERE id = service_id AND vendor_id = auth.uid()) AND auth.role() = 'vendor');