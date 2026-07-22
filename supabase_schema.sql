-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. USER PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier TEXT DEFAULT 'free',
  subscription_ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS & Policies for user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile" 
  ON public.user_profiles FOR SELECT 
  TO authenticated 
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update their own profile" 
  ON public.user_profiles FOR UPDATE 
  TO authenticated 
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "Users can insert their profile" 
  ON public.user_profiles FOR INSERT 
  TO authenticated 
  WITH CHECK ((SELECT auth.uid()) = id);


-- 2. MOVIES TABLE
CREATE TABLE IF NOT EXISTS public.movies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  overview TEXT,
  poster_url TEXT,
  source TEXT,
  is_netflix BOOLEAN DEFAULT FALSE,
  is_cinema BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS & Policies for movies
ALTER TABLE public.movies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view movies" 
  ON public.movies FOR SELECT 
  TO anon, authenticated 
  USING (true);

CREATE POLICY "Authenticated users can insert movies" 
  ON public.movies FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update movies" 
  ON public.movies FOR UPDATE 
  TO authenticated 
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Authenticated users can delete movies" 
  ON public.movies FOR DELETE 
  TO authenticated 
  USING (true);


-- 3. SHORTLIST ITEMS TABLE
CREATE TABLE IF NOT EXISTS public.shortlist_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  movie_id UUID NOT NULL REFERENCES public.movies(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, movie_id)
);

-- Enable RLS & Policies for shortlist_items
ALTER TABLE public.shortlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their shortlist items" 
  ON public.shortlist_items FOR SELECT 
  TO authenticated 
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can add shortlist items" 
  ON public.shortlist_items FOR INSERT 
  TO authenticated 
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Users can delete shortlist items" 
  ON public.shortlist_items FOR DELETE 
  TO authenticated 
  USING ((SELECT auth.uid()) = user_id);


-- 4. ROOMS TABLE
CREATE TABLE IF NOT EXISTS public.rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS & Policies for rooms
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view rooms" 
  ON public.rooms FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Authenticated users can create rooms" 
  ON public.rooms FOR INSERT 
  TO authenticated 
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Owners can update rooms" 
  ON public.rooms FOR UPDATE 
  TO authenticated 
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Owners can delete rooms" 
  ON public.rooms FOR DELETE 
  TO authenticated 
  USING ((SELECT auth.uid()) = owner_id);


-- 5. ROOM PARTICIPANTS TABLE
CREATE TABLE IF NOT EXISTS public.room_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'participant',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(room_id, user_id)
);

-- Enable RLS & Policies for room_participants
ALTER TABLE public.room_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Participants can view room participants" 
  ON public.room_participants FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Authenticated users can join rooms" 
  ON public.room_participants FOR INSERT 
  TO authenticated 
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Participants can leave rooms" 
  ON public.room_participants FOR DELETE 
  TO authenticated 
  USING ((SELECT auth.uid()) = user_id);


-- 6. ROUNDS TABLE
CREATE TABLE IF NOT EXISTS public.rounds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'active',
  winner_movie_id UUID REFERENCES public.movies(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS & Policies for rounds
ALTER TABLE public.rounds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view rounds" 
  ON public.rounds FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Authenticated users can create rounds" 
  ON public.rounds FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Authenticated users can update rounds" 
  ON public.rounds FOR UPDATE 
  TO authenticated 
  USING (true)
  WITH CHECK (true);


-- 7. ROUND MOVIES TABLE
CREATE TABLE IF NOT EXISTS public.round_movies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES public.rounds(id) ON DELETE CASCADE,
  movie_id UUID NOT NULL REFERENCES public.movies(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(round_id, movie_id)
);

-- Enable RLS & Policies for round_movies
ALTER TABLE public.round_movies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view round movies" 
  ON public.round_movies FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Authenticated users can insert round movies" 
  ON public.round_movies FOR INSERT 
  TO authenticated 
  WITH CHECK (true);


-- 8. SWIPES TABLE
CREATE TABLE IF NOT EXISTS public.swipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  round_id UUID NOT NULL REFERENCES public.rounds(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  movie_id UUID NOT NULL REFERENCES public.movies(id) ON DELETE CASCADE,
  vote TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(round_id, user_id, movie_id)
);

-- Enable RLS & Policies for swipes
ALTER TABLE public.swipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can view swipes" 
  ON public.swipes FOR SELECT 
  TO authenticated 
  USING (true);

CREATE POLICY "Users can log their own swipes" 
  ON public.swipes FOR INSERT 
  TO authenticated 
  WITH CHECK ((SELECT auth.uid()) = user_id);


-- 9. ACTION LOGS TABLE
CREATE TABLE IF NOT EXISTS public.action_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS & Policies for action_logs
ALTER TABLE public.action_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can insert action logs" 
  ON public.action_logs FOR INSERT 
  TO authenticated 
  WITH CHECK (true);

CREATE POLICY "Authenticated users can view action logs" 
  ON public.action_logs FOR SELECT 
  TO authenticated 
  USING (true);


-- AUTOMATIC USER PROFILE TRIGGER
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, tier)
  VALUES (new.id, 'free')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
