# Supabase Setup

This directory contains the Supabase configuration and migrations for the GitFluent application.

## Prerequisites

1. Create a Supabase account at [https://supabase.com](https://supabase.com)
2. Create a new project in Supabase
3. Get your project URL and anon key from the project settings

## Environment Variables

Create a `.env` file in the root directory with the following variables:

```env
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

## Database Setup

1. Go to your Supabase project dashboard
2. Navigate to the SQL editor
3. Copy the contents of `migrations/20240321000000_initial_schema.sql`
4. Run the SQL script to create the database schema

## Authentication Setup

1. Go to Authentication > Providers in your Supabase dashboard
2. Enable the following providers:
   - Email/Password
   - Google
   - Apple (if needed)

### Google OAuth Setup

1. Go to the Google Cloud Console
2. Create a new project or select an existing one
3. Enable the Google+ API
4. Create OAuth 2.0 credentials
5. Add your authorized redirect URI from Supabase
6. Copy the Client ID and Client Secret to Supabase

### Apple OAuth Setup (Optional)

1. Go to the Apple Developer Console
2. Create a new App ID
3. Enable Sign In with Apple
4. Create a Service ID
5. Configure the domains and redirect URIs
6. Create a key for Sign In with Apple
7. Copy the credentials to Supabase

## Storage Setup

1. Go to Storage in your Supabase dashboard
2. Create a new bucket called `user-profiles`
3. Set the bucket's privacy to private
4. Add the following RLS policy:

```sql
CREATE POLICY "Users can upload their own profile images"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'user-profiles' AND
  auth.uid() = (storage.foldername(name))[1]::uuid
);

CREATE POLICY "Users can view their own profile images"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'user-profiles' AND
  auth.uid() = (storage.foldername(name))[1]::uuid
);
```

## Testing

1. Go to Authentication > Users in your Supabase dashboard
2. Create a test user with email/password
3. Try signing in with the test user
4. Verify that the user can access their data
5. Test the premium user restrictions

## Troubleshooting

- If you encounter authentication issues, check the OAuth configuration
- For database errors, verify the RLS policies
- Check the Supabase logs for detailed error messages

## Security Notes

- Never commit your `.env` file
- Keep your anon key secure
- Regularly rotate your service role key
- Monitor your database for suspicious activity 