# NutriAI: setup guide (free, private, works on iPhone without your PC)

NutriAI is now a **web app that installs on the iPhone home screen**. You share one free
link; people create an account; **nobody can use the app until you approve them** in the
Admin screen. Everything runs online for free:

| Part | Service | Cost |
|---|---|---|
| Login, database, profile photos, AI server function | Supabase (free plan) | 0, no card |
| AI photo recognition | Groq (free tier) | 0, no card |
| Nutrition values | USDA FoodData Central (free key) | 0 |
| The app link (https) | Cloudflare Pages (free plan) | 0, no card |

Time needed: about 45 minutes the first time.

**Extract this project into a new, empty folder** (not over the old one; see CHANGES.md).

You need on your PC: Flutter (already installed), a web browser. Optional: Node.js
(only for `deploy_web.bat`).

---

## Step 1. Create the Supabase project

1. Go to https://supabase.com, sign up (free, no card), click **New project**.
   Pick a region close to you (for example Frankfurt), set a database password and keep it.
2. When the project is ready, open **Project Settings > API** (or **API Keys**) and copy:
   * the **Project URL** (looks like `https://abcdefgh.supabase.co`)
   * the **anon public** key (or the **publishable** key `sb_publishable_...`).
   These two are public by design. NEVER use the `service_role` / secret key in the app.
3. In this project folder, copy `config.example.json` to `config.json` and paste the two
   values in. `config.json` is ignored by git.

## Step 2. Create the database

1. Supabase > **SQL Editor** > **New query**.
2. Open `supabase/SETUP_DATABASE.sql` from this folder, copy everything, paste, click **Run**.
   It should end with "Success". (It is safe to run again later.)
3. Security self-test: new query, paste `supabase/tests/rls_check.sql`, click **Run**.
   You must see an error message that says
   **"RLS SELF-TEST: ALL 16 CHECKS PASSED"**. It is shown as an error on purpose so the
   4 temporary test accounts are rolled back. Any other message means something is wrong:
   send it to Claude.

## Step 3. Login settings

Supabase > **Authentication**:

1. **Sign In / Providers > Email**: keep Email enabled, **turn OFF "Confirm email"**, Save.
   Reason: your admin approval is the real gate, and Supabase's free email sender only
   delivers to members of your Supabase team, so confirmation emails would never reach
   your users.
2. Optional: **Passwords**: minimum length 8 (the app already asks for 8).
3. **URL Configuration**: you will fill this in at step 7, once you have your app link.

## Step 4. AI and nutrition keys (stored on the server, never in the app)

1. **Groq**: https://console.groq.com > sign up (no card) > **API Keys** > **Create API Key**.
   Copy it (starts with `gsk_`).
2. **USDA**: https://fdc.nal.usda.gov/api-key-signup > fill the form > the key arrives by email.
3. Supabase > **Edge Functions > Secrets** (or Project Settings > Edge Functions): add
   * `GROQ_API_KEY` = your Groq key
   * `USDA_API_KEY` = your USDA key
4. Revoke the old Gemini key that was written in the old source code
   (Google Cloud console > APIs & Services > Credentials). It is no longer used.

## Step 5. Deploy the AI function

Supabase > **Edge Functions** > **Deploy a new function** > **Via Editor**:

1. Name: `analyze-food` (exactly this).
2. Delete the example code, paste the whole file
   `supabase/functions/analyze-food/index.ts`, click **Deploy**.
3. Open the function's **Settings / Details** and turn **OFF** "Verify JWT" (sometimes
   called "Enforce JWT verification"). The function checks the login and the approval
   itself; leaving it on can block valid users on newer Supabase projects.

Alternative with the command line (from this folder, needs Node.js):
`npx supabase functions deploy analyze-food --no-verify-jwt --project-ref YOUR_PROJECT_ID`

## Step 6. First test on your PC

1. Double-click `check_code.bat`. It downloads packages, checks the code and runs the
   unit tests. If you see errors, copy the text and send it to Claude.
2. Double-click `run_web.bat`. Chrome opens the app.
3. Create your own account (Register). You will see **"Waiting for approval"**. Correct!
4. Make yourself the admin: Supabase > SQL Editor, run (with YOUR email):

   ```sql
   UPDATE public.profiles SET is_admin = TRUE, status = 'approved'
   WHERE email = 'your.email@example.com';
   ```

5. In the app press **Check again**. You now go through body profile and goal setup.
6. Try: dashboard, diary, food search, a gallery photo in the scanner, profile photo.

## Step 7. Publish your free app link

### Option A (recommended): automatic from GitHub

The project contains `.github/workflows/build-web.yml`. Every time the code on the `main`
branch changes, GitHub builds the web app (free) and puts the result on the branch
`web-build`. Cloudflare publishes that branch. You never need to build on your PC.

1. Push the project to a GitHub repository (private is fine).
2. Open the repository > **Actions**. Wait until "Build web app" shows a green tick
   (about 5 minutes). The branch `web-build` now exists.
3. https://dash.cloudflare.com (sign up free, no card) > **Workers & Pages** >
   **Create application** > "Looking to deploy Pages? **Get started**" >
   **Import an existing Git repository** > connect GitHub > pick the repository.
4. Settings on the next screen:
   * **Production branch**: `web-build`
   * **Framework preset**: None
   * **Build command**: leave empty
   * **Build output directory**: `/`
   Click **Save and Deploy**. Your link is `https://<project-name>.pages.dev`.
5. Important: open the Cloudflare project > **Settings** > **Builds** > **Branch control**
   and set **Preview branch** to **None**. Otherwise Cloudflare would also publish the
   source code of the `main` branch on a preview link.
6. Supabase > **Authentication > URL Configuration**: set **Site URL** to your link and add
   it to **Redirect URLs**.

Updating later: change the code and push to `main`. About 5 minutes later the new version
is online.

### Option B: upload by hand

1. Double-click `build_web.bat`. When it says Done, the app is in the folder `build\web`.
2. Go to https://dash.cloudflare.com (sign up free, no card) > **Workers & Pages** >
   **Create** > **Pages** > **Upload assets** (Direct Upload).
3. Project name: `nutriai` (your link becomes `https://nutriai.pages.dev`, or a similar
   name if it is taken). Drag the **build\web** folder in, click **Deploy**.
4. Back in Supabase > **Authentication > URL Configuration**:
   * **Site URL**: your link, for example `https://nutriai.pages.dev`
   * **Redirect URLs**: add the same link.

Updating later: change the code, run `build_web.bat`, then in Cloudflare open the project >
**Create deployment** > drag `build\web` again. Everyone gets the new version the next time
they open the app. (Or use `deploy_web.bat`, which does build and upload in one step.)

## Step 8. Install on the iPhone

1. Open your link **in Safari** on the iPhone.
2. Tap **Share** (square with arrow) > **Add to Home Screen** > **Add**.
3. Open NutriAI from the new icon: it runs full screen like an app, with no PC needed.
4. Sign in. When you open the scanner, allow camera access.
   If you blocked it by mistake: iPhone Settings > Safari > Camera > Ask/Allow.

## Step 9. Give the app to other people

1. Send them the link and these "Add to Home Screen" steps.
2. They register and see "Waiting for approval".
3. You: Profile (top right on the dashboard) > **Admin: manage access** > Waiting > **Approve**.
   Tap a person for more options:
   * **Approve until a date** (for monthly payments, access stops automatically)
   * **Revoke access** / **Reject**
   * **Set a temporary password** (when someone forgot their password)
   * **Delete user and all data**

People who are not approved cannot read or write anything: this is enforced by the
database itself (step 2 self-test), not only hidden in the app.

---

## Test checklist (do these before giving the app to others)

| # | Test | How | OK? |
|---|---|---|---|
| 1 | Registration | Register a 2nd account (other email) on the iPhone | |
| 2 | Waiting screen | The new account sees "Waiting for approval" | |
| 3 | Approval | Approve it in Admin, press "Check again" on the phone | |
| 4 | Existing-account login | Sign out, sign in again | |
| 5 | Session persistence | Close the app fully, reopen from the icon: still signed in | |
| 6 | Profile photo upload | Profile > camera icon > gallery | |
| 7 | Photo after restart / other device | Reopen the app, open the link on the PC: same photo | |
| 8 | Camera capture | Scanner > shutter (or "Use camera app") | |
| 9 | Gallery analysis | Scanner > gallery | |
| 10 | Real AI recognition, several foods | Photo of a plate with 2 to 3 foods | |
| 11 | Nutrition values | Each item shows "Source: USDA..." or "Tunisian dishes" | |
| 12 | Manual correction | Change grams, "Wrong food? Tap to change", add missing food | |
| 13 | Diary persistence | Save meal, reopen app, check Diary | |
| 14 | Multi-user isolation | Account B must not see account A's diary (also step 2 self-test) | |
| 15 | Revoke | Revoke account B: it is blocked at the next "Check again"/restart | |
| 16 | Password help | Admin > set temporary password, sign in with it | |

---

## Troubleshooting

| You see | Fix |
|---|---|
| "Setup needed" screen | `config.json` is missing or wrong (step 1.3). Use the .bat files. |
| "AI is not configured yet" | Add the `GROQ_API_KEY` secret (step 4). |
| "Edge Function analyze-food not found" | Deploy the function with that exact name (step 5). |
| "Your session expired" when scanning | Turn off "Verify JWT" on the function (step 5.3). |
| "The free AI limit is reached" | Groq free tier limit; wait a minute. |
| Items say "AI estimate (no database match)" | Normal for unusual foods. Check that `USDA_API_KEY` is set. |
| "This photo format is not supported" | iPhone Settings > Camera > Formats > **Most Compatible**. |
| Live camera stays black | Close and reopen the scanner, or use "Use camera app instead". |
| Can't receive reset emails | Expected without own email setup: use Admin > temporary password, or see "Optional" below. |
| Supabase project "paused" | Free projects pause after about a week with no use. Supabase dashboard > Restore. |

## Optional extras

* **Password reset emails for everyone**: Supabase > Authentication > Emails > SMTP Settings >
  enable custom SMTP (free options: a Gmail account with an "app password", or Brevo free
  plan). Then edit the **Reset Password** email template and add the code:
  `Your code: {{ .Token }}`. The app's "Forgot password" screen accepts the code.
* **Switch the AI to Google Gemini** later: add secrets `AI_PROVIDER = gemini` and
  `GEMINI_API_KEY`. Note: Google only allows its paid tier for apps used by people in the
  EU, Switzerland or the UK.
* **Different AI model**: secret `AI_MODEL` (default `qwen/qwen3.8-27b` on Groq).
* **Native iPhone app later**: the iOS project is kept and prepared (permissions, icon,
  iOS 13). Publishing it requires the paid Apple Developer Program.

## Limits of the free plans (good to know)

* Supabase free: 500 MB database, 1 GB photo storage, no automatic backups,
  pauses after about 7 days without any use.
* Groq free: rate limited (around 30 photo analyses per minute for the whole app).
* USDA key: 1,000 lookups per hour.
* Cloudflare Pages free: unlimited visits to the app.
