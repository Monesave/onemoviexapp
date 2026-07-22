## Onemoviex Flutter Web App

This is the **Flutter Web** implementation of the Onemoviex app, deployed as a web application.

### Prerequisites

- Install Flutter: follow the official docs at `https://docs.flutter.dev/get-started/install`
- Enable web support: `flutter config --enable-web`

### First-time setup

From the repo root:

```bash
cd apps/onemoviex_flutter
flutter pub get
```

Then configure **Supabase**:

1. Create a Supabase project at `https://supabase.com` (if you haven’t already).
2. Go to **Project Settings → API** and find:
   - **Project URL**
   - **anon public key**
3. Open `lib/env.dart` and replace:
   - `supabaseUrl` with your **Project URL**
   - `supabaseAnonKey` with your **anon public key**

### Run the app locally

- **Web (Chrome)**:

  ```bash
  flutter run -d chrome
  ```

You should first see a **sign-in screen**:

- Enter an **email** and **password**.
- Click **"Sign in"**:
  - If the user exists and the password is correct, you'll be taken to the Onemoviex home screen.
  - If the user does not exist yet, click **"Create an account"** to sign up.

After signing in, you’ll see the **Onemoviex** home screen with:

- A gradient background
- A **“Get started”** button (placeholder for future flows)
- A **“Rooms”** button (for room creation/joining)
- A **“Test Supabase connection”** button
- A **logout icon** in the top-right of the app bar

- Click **"Test Supabase connection"**:
  - If your Supabase project is set up and a `movies` table exists, you'll see a success message.
  - If the table is missing or something is wrong, you'll see an error message in a snackbar.

### Web Deployment

The app is deployed as a web application using:

- **Vercel** - Frontend hosting for the Flutter web build
- **Railway** - Backend services (if needed)
- **Hostinger** - Domain hosting

See `DEPLOYMENT.md` for detailed deployment instructions.

### Next steps

- Add movies to your Supabase `movies` table so they appear in the **Movies** list.
- Use the heart icon on each movie to add/remove it from your **shortlist**.
- Open **“My shortlist”** from the home screen app bar to see and manage saved movies.
- Use **“Rooms”** on the home screen to:
  - **Create a room** (you become the owner and participant).
  - **Join a room** by pasting a room ID that someone else shares.
- Later steps will add:
  - Swiping UI and rounds
  - Rooms and group decision logic
  - Mood-based suggestions and winner actions



