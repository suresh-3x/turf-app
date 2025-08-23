-- Create bookings table
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    service_id UUID REFERENCES services(id) ON DELETE CASCADE,
    slot_id UUID REFERENCES slots(id) ON DELETE CASCADE,
    booking_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'pending' -- 'pending', 'confirmed', 'cancelled', 'completed'
);

-- Enable Row Level Security (RLS) for the bookings table
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view their own bookings
CREATE POLICY "Allow authenticated users to view their own bookings" ON bookings
FOR SELECT USING (auth.uid() = customer_id OR EXISTS (SELECT 1 FROM services WHERE id = service_id AND vendor_id = auth.uid()));

-- Allow customers to create bookings
CREATE POLICY "Allow customers to create bookings" ON bookings
FOR INSERT WITH CHECK (auth.uid() = customer_id AND auth.role() = 'customer');

-- Allow customers to cancel their own pending bookings
CREATE POLICY "Allow customers to cancel their own pending bookings" ON bookings
FOR UPDATE USING (auth.uid() = customer_id AND status = 'pending') WITH CHECK (status = 'cancelled');

-- Allow vendors to update the status of bookings for their services
CREATE POLICY "Allow vendors to update booking status" ON bookings
FOR UPDATE USING (EXISTS (SELECT 1 FROM services WHERE id = service_id AND vendor_id = auth.uid()) AND auth.role() = 'vendor');