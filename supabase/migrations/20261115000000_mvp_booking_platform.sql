-- =============================================================================
-- MVP booking platform
--
-- Builds on the 2023-11-20 migrations. It fixes problems in them and adds what
-- the app needs:
--   * users.id is now tied to auth.users, and a profile row is created
--     automatically on sign-up (name + role come from sign-up metadata).
--   * Role checks used auth.role() = 'vendor'/'customer', which never matches
--     (auth.role() is 'authenticated'). They now use public.current_user_role().
--   * Booking a slot, changing a booking's status and freeing the slot happen
--     inside SECURITY DEFINER functions, so they are atomic and a slot can never
--     be double-booked.
--   * Reviews are linked to a service, one per booking.
--   * In-app notifications are written by triggers when bookings change.
--
-- Safe to run whether or not the earlier migrations' data exists, but it
-- assumes no real user data (users.id is re-pointed at auth.users).
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- -----------------------------------------------------------------------------
-- users
-- -----------------------------------------------------------------------------
ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Remove profiles that do not belong to an auth user, then link the two.
DELETE FROM public.users u WHERE NOT EXISTS (SELECT 1 FROM auth.users a WHERE a.id = u.id);
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_id_fkey;
ALTER TABLE public.users
  ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE public.users ADD CONSTRAINT users_role_check CHECK (role IN ('customer', 'vendor'));

-- Role of the signed-in user. SECURITY DEFINER so policies can call it without
-- recursing through the users table's own policies.
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT role FROM public.users WHERE id = auth.uid();
$$;

-- Create the profile when someone signs up. Works with email confirmation on,
-- where the client has no session yet and could not insert the row itself.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_role TEXT := COALESCE(NEW.raw_user_meta_data ->> 'role', 'customer');
BEGIN
  IF v_role NOT IN ('customer', 'vendor') THEN
    v_role := 'customer';
  END IF;
  INSERT INTO public.users (id, name, email, role, phone)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(NEW.raw_user_meta_data ->> 'name', ''), split_part(NEW.email, '@', 1)),
    NEW.email,
    v_role,
    NULLIF(NEW.raw_user_meta_data ->> 'phone', '')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Users may not change their own role or email through the API.
CREATE OR REPLACE FUNCTION public.protect_user_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF auth.uid() IS NOT NULL THEN
    NEW.role := OLD.role;
    NEW.email := OLD.email;
    NEW.id := OLD.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_user_columns ON public.users;
CREATE TRIGGER protect_user_columns
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.protect_user_columns();

-- -----------------------------------------------------------------------------
-- services
-- -----------------------------------------------------------------------------
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS price_per_slot NUMERIC(10, 2) NOT NULL DEFAULT 0;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE public.services ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.services ALTER COLUMN vendor_id SET NOT NULL;
ALTER TABLE public.services DROP CONSTRAINT IF EXISTS services_price_check;
ALTER TABLE public.services ADD CONSTRAINT services_price_check CHECK (price_per_slot >= 0);
CREATE INDEX IF NOT EXISTS services_vendor_id_idx ON public.services (vendor_id);
CREATE INDEX IF NOT EXISTS services_category_idx ON public.services (category);

-- -----------------------------------------------------------------------------
-- slots
-- -----------------------------------------------------------------------------
ALTER TABLE public.slots ALTER COLUMN service_id SET NOT NULL;
ALTER TABLE public.slots ALTER COLUMN is_booked SET NOT NULL;
ALTER TABLE public.slots DROP CONSTRAINT IF EXISTS slots_time_check;
ALTER TABLE public.slots ADD CONSTRAINT slots_time_check CHECK (end_time > start_time);
-- A service cannot have two slots that overlap in time.
ALTER TABLE public.slots DROP CONSTRAINT IF EXISTS slots_no_overlap;
ALTER TABLE public.slots
  ADD CONSTRAINT slots_no_overlap
  EXCLUDE USING gist (service_id WITH =, tstzrange(start_time, end_time) WITH &&);
CREATE INDEX IF NOT EXISTS slots_service_start_idx ON public.slots (service_id, start_time);

-- -----------------------------------------------------------------------------
-- bookings
-- -----------------------------------------------------------------------------
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.bookings ALTER COLUMN customer_id SET NOT NULL;
ALTER TABLE public.bookings ALTER COLUMN service_id SET NOT NULL;
ALTER TABLE public.bookings ALTER COLUMN slot_id SET NOT NULL;
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE public.bookings
  ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending', 'confirmed', 'rejected', 'cancelled', 'completed'));
-- At most one live booking per slot.
CREATE UNIQUE INDEX IF NOT EXISTS bookings_one_active_per_slot
  ON public.bookings (slot_id) WHERE status IN ('pending', 'confirmed', 'completed');
CREATE INDEX IF NOT EXISTS bookings_customer_idx ON public.bookings (customer_id);
CREATE INDEX IF NOT EXISTS bookings_service_idx ON public.bookings (service_id);

-- -----------------------------------------------------------------------------
-- reviews
-- -----------------------------------------------------------------------------
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS service_id UUID REFERENCES public.services(id) ON DELETE CASCADE;
-- Reviewer's display name, copied at write time (customers cannot read each
-- other's profiles).
ALTER TABLE public.reviews ADD COLUMN IF NOT EXISTS customer_name TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS reviews_one_per_booking ON public.reviews (booking_id);
CREATE INDEX IF NOT EXISTS reviews_service_idx ON public.reviews (service_id);

-- Fill service_id/vendor_id/customer from the booking so the client cannot
-- spoof them.
CREATE OR REPLACE FUNCTION public.fill_review_links()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  SELECT b.service_id, s.vendor_id, b.customer_id
    INTO NEW.service_id, NEW.vendor_id, NEW.customer_id
  FROM public.bookings b
  JOIN public.services s ON s.id = b.service_id
  WHERE b.id = NEW.booking_id;
  SELECT name INTO NEW.customer_name FROM public.users WHERE id = NEW.customer_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS fill_review_links ON public.reviews;
CREATE TRIGGER fill_review_links
  BEFORE INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.fill_review_links();

-- Average rating per service.
CREATE OR REPLACE VIEW public.service_ratings
WITH (security_invoker = true) AS
SELECT service_id,
       ROUND(AVG(rating)::numeric, 1) AS average_rating,
       COUNT(*)::int AS review_count
FROM public.reviews
WHERE service_id IS NOT NULL
GROUP BY service_id;

-- -----------------------------------------------------------------------------
-- notifications (in-app)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE CASCADE,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications (user_id, created_at DESC);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_booking_change()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_service_name TEXT;
  v_vendor_id UUID;
  v_customer_name TEXT;
  v_when TEXT;
BEGIN
  SELECT s.name, s.vendor_id INTO v_service_name, v_vendor_id
  FROM public.services s WHERE s.id = NEW.service_id;
  SELECT u.name INTO v_customer_name FROM public.users u WHERE u.id = NEW.customer_id;
  SELECT to_char(sl.start_time AT TIME ZONE 'UTC', 'DD Mon HH24:MI "UTC"') INTO v_when
  FROM public.slots sl WHERE sl.id = NEW.slot_id;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.notifications (user_id, title, body, booking_id)
    VALUES (v_vendor_id, 'New booking request',
            COALESCE(v_customer_name, 'A customer') || ' requested ' || v_service_name || ' on ' || v_when,
            NEW.id);
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.status IN ('confirmed', 'rejected', 'completed') THEN
      INSERT INTO public.notifications (user_id, title, body, booking_id)
      VALUES (NEW.customer_id,
              'Booking ' || NEW.status,
              'Your booking for ' || v_service_name || ' on ' || v_when || ' was ' || NEW.status || '.',
              NEW.id);
    ELSIF NEW.status = 'cancelled' THEN
      -- Tell whoever did not cancel it.
      INSERT INTO public.notifications (user_id, title, body, booking_id)
      VALUES (CASE WHEN auth.uid() = NEW.customer_id THEN v_vendor_id ELSE NEW.customer_id END,
              'Booking cancelled',
              'The booking for ' || v_service_name || ' on ' || v_when || ' was cancelled.',
              NEW.id);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_booking_change ON public.bookings;
CREATE TRIGGER notify_booking_change
  AFTER INSERT OR UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.notify_booking_change();

-- -----------------------------------------------------------------------------
-- Booking functions (the only way bookings are created or change status)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.book_slot(p_slot_id UUID, p_notes TEXT DEFAULT NULL)
RETURNS public.bookings
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_slot public.slots;
  v_service public.services;
  v_booking public.bookings;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'You must be signed in to book.';
  END IF;
  IF public.current_user_role() IS DISTINCT FROM 'customer' THEN
    RAISE EXCEPTION 'Only customer accounts can make bookings.';
  END IF;

  -- Lock the slot so two people cannot book it at once.
  SELECT * INTO v_slot FROM public.slots WHERE id = p_slot_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'This slot no longer exists.';
  END IF;
  IF v_slot.is_booked THEN
    RAISE EXCEPTION 'Sorry, this slot has just been booked by someone else.';
  END IF;
  IF v_slot.start_time <= now() THEN
    RAISE EXCEPTION 'This slot has already started.';
  END IF;

  SELECT * INTO v_service FROM public.services WHERE id = v_slot.service_id;
  IF NOT v_service.is_active THEN
    RAISE EXCEPTION 'This service is not taking bookings right now.';
  END IF;

  INSERT INTO public.bookings (customer_id, service_id, slot_id, status, notes)
  VALUES (auth.uid(), v_slot.service_id, v_slot.id, 'pending', NULLIF(trim(p_notes), ''))
  RETURNING * INTO v_booking;

  UPDATE public.slots SET is_booked = TRUE WHERE id = v_slot.id;
  RETURN v_booking;
END;
$$;

-- Allowed transitions:
--   customer: pending|confirmed -> cancelled (before the slot starts)
--   vendor:   pending -> confirmed|rejected
--             confirmed -> completed|cancelled
CREATE OR REPLACE FUNCTION public.update_booking_status(p_booking_id UUID, p_status TEXT)
RETURNS public.bookings
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_booking public.bookings;
  v_vendor_id UUID;
  v_start TIMESTAMPTZ;
  v_is_customer BOOLEAN;
  v_is_vendor BOOLEAN;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Booking not found.';
  END IF;
  SELECT vendor_id INTO v_vendor_id FROM public.services WHERE id = v_booking.service_id;
  SELECT start_time INTO v_start FROM public.slots WHERE id = v_booking.slot_id;

  v_is_customer := auth.uid() = v_booking.customer_id;
  v_is_vendor := auth.uid() = v_vendor_id;

  IF v_is_customer AND p_status = 'cancelled' AND v_booking.status IN ('pending', 'confirmed') THEN
    IF v_start <= now() THEN
      RAISE EXCEPTION 'This booking has already started and can no longer be cancelled.';
    END IF;
  ELSIF v_is_vendor AND (
        (v_booking.status = 'pending' AND p_status IN ('confirmed', 'rejected'))
     OR (v_booking.status = 'confirmed' AND p_status IN ('completed', 'cancelled'))
  ) THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'You cannot change this booking from % to %.', v_booking.status, p_status;
  END IF;

  UPDATE public.bookings
     SET status = p_status, updated_at = now()
   WHERE id = p_booking_id
  RETURNING * INTO v_booking;

  -- Give the slot back if the booking will not happen.
  IF p_status IN ('cancelled', 'rejected') THEN
    UPDATE public.slots SET is_booked = FALSE WHERE id = v_booking.slot_id;
  END IF;
  RETURN v_booking;
END;
$$;

REVOKE ALL ON FUNCTION public.book_slot(UUID, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_booking_status(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.book_slot(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_booking_status(UUID, TEXT) TO authenticated;

-- -----------------------------------------------------------------------------
-- Row-level security policies (replace the earlier ones)
-- -----------------------------------------------------------------------------

-- users
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can delete their own profile" ON public.users;
DROP POLICY IF EXISTS "New users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "users_select_own" ON public.users;
DROP POLICY IF EXISTS "users_select_vendors" ON public.users;
DROP POLICY IF EXISTS "users_select_my_customers" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;

CREATE POLICY "users_select_own" ON public.users
  FOR SELECT TO authenticated USING (id = auth.uid());
-- Vendor profiles are public to signed-in users (business contact details).
CREATE POLICY "users_select_vendors" ON public.users
  FOR SELECT TO authenticated USING (role = 'vendor');
-- Vendors can see the customers who booked them.
CREATE POLICY "users_select_my_customers" ON public.users
  FOR SELECT TO authenticated USING (EXISTS (
    SELECT 1 FROM public.bookings b JOIN public.services s ON s.id = b.service_id
    WHERE b.customer_id = users.id AND s.vendor_id = auth.uid()
  ));
CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE TO authenticated USING (id = auth.uid()) WITH CHECK (id = auth.uid());

-- services
DROP POLICY IF EXISTS "Allow authenticated users to view services" ON public.services;
DROP POLICY IF EXISTS "Allow vendors to insert their own services" ON public.services;
DROP POLICY IF EXISTS "Allow vendors to update their own services" ON public.services;
DROP POLICY IF EXISTS "Allow vendors to delete their own services" ON public.services;
DROP POLICY IF EXISTS "services_select" ON public.services;
DROP POLICY IF EXISTS "services_insert_vendor" ON public.services;
DROP POLICY IF EXISTS "services_update_vendor" ON public.services;
DROP POLICY IF EXISTS "services_delete_vendor" ON public.services;

-- Readable by all signed-in users so past bookings still show a service after
-- it is deactivated; the browse screen filters on is_active.
CREATE POLICY "services_select" ON public.services
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "services_insert_vendor" ON public.services
  FOR INSERT TO authenticated
  WITH CHECK (vendor_id = auth.uid() AND public.current_user_role() = 'vendor');
CREATE POLICY "services_update_vendor" ON public.services
  FOR UPDATE TO authenticated
  USING (vendor_id = auth.uid()) WITH CHECK (vendor_id = auth.uid());
CREATE POLICY "services_delete_vendor" ON public.services
  FOR DELETE TO authenticated USING (vendor_id = auth.uid());

-- slots
DROP POLICY IF EXISTS "Allow authenticated users to view slots" ON public.slots;
DROP POLICY IF EXISTS "Allow vendors to insert their own slots" ON public.slots;
DROP POLICY IF EXISTS "Allow vendors to update their own slots" ON public.slots;
DROP POLICY IF EXISTS "Allow vendors to delete their own slots" ON public.slots;
DROP POLICY IF EXISTS "slots_select" ON public.slots;
DROP POLICY IF EXISTS "slots_insert_vendor" ON public.slots;
DROP POLICY IF EXISTS "slots_update_vendor" ON public.slots;
DROP POLICY IF EXISTS "slots_delete_vendor" ON public.slots;

CREATE POLICY "slots_select" ON public.slots
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "slots_insert_vendor" ON public.slots
  FOR INSERT TO authenticated WITH CHECK (
    is_booked = FALSE AND
    EXISTS (SELECT 1 FROM public.services s WHERE s.id = service_id AND s.vendor_id = auth.uid())
  );
-- Vendors may move or delete only slots nobody has booked; is_booked itself is
-- managed by the booking functions.
CREATE POLICY "slots_update_vendor" ON public.slots
  FOR UPDATE TO authenticated
  USING (is_booked = FALSE AND EXISTS (SELECT 1 FROM public.services s WHERE s.id = service_id AND s.vendor_id = auth.uid()))
  WITH CHECK (is_booked = FALSE AND EXISTS (SELECT 1 FROM public.services s WHERE s.id = service_id AND s.vendor_id = auth.uid()));
CREATE POLICY "slots_delete_vendor" ON public.slots
  FOR DELETE TO authenticated
  USING (is_booked = FALSE AND EXISTS (SELECT 1 FROM public.services s WHERE s.id = service_id AND s.vendor_id = auth.uid()));

-- bookings: read-only through the API; writes go through the functions above.
DROP POLICY IF EXISTS "Allow authenticated users to view their own bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow customers to create bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow customers to cancel their own pending bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow vendors to update booking status" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select" ON public.bookings;

CREATE POLICY "bookings_select" ON public.bookings
  FOR SELECT TO authenticated USING (
    customer_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.services s WHERE s.id = service_id AND s.vendor_id = auth.uid())
  );

-- reviews
DROP POLICY IF EXISTS "Allow authenticated users to view reviews" ON public.reviews;
DROP POLICY IF EXISTS "Allow customers to insert reviews" ON public.reviews;
DROP POLICY IF EXISTS "reviews_select" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert_customer" ON public.reviews;

CREATE POLICY "reviews_select" ON public.reviews
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "reviews_insert_customer" ON public.reviews
  FOR INSERT TO authenticated WITH CHECK (
    customer_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id AND b.customer_id = auth.uid() AND b.status = 'completed'
    )
  );

-- notifications
DROP POLICY IF EXISTS "notifications_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete_own" ON public.notifications;

CREATE POLICY "notifications_select_own" ON public.notifications
  FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "notifications_update_own" ON public.notifications
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
CREATE POLICY "notifications_delete_own" ON public.notifications
  FOR DELETE TO authenticated USING (user_id = auth.uid());
