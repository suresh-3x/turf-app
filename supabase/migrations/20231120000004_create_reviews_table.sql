-- Create reviews table
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    vendor_id UUID REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security (RLS) for the reviews table
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to view all reviews
CREATE POLICY "Allow authenticated users to view reviews" ON reviews
FOR SELECT USING (auth.role() = 'authenticated');

-- Allow customers to insert reviews for their completed bookings
CREATE POLICY "Allow customers to insert reviews" ON reviews
FOR INSERT WITH CHECK (auth.uid() = customer_id AND auth.role() = 'customer' AND EXISTS (SELECT 1 FROM bookings WHERE id = booking_id AND customer_id = auth.uid() AND status = 'completed'));