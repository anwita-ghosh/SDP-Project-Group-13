# Loksewa Education Aid Portal

A prototype portal that connects students (kindergarten to postgraduate) with scholarships and sponsors, built for Loksewa Social Foundation.

- **Students and families:** search programs, apply with document upload, track an application.
- **Sponsors:** record one-time or monthly pledges, or sponsor a student profile.
- **Staff:** sign in, review applications, view documents, update statuses, log disbursements, manage programs, view pledges.

All people, programs, figures and fund-usage percentages in the sample data are **fictional**.

---

## How it works

Static HTML pages talk directly to a **Supabase** (Postgres) project. There is no server of our own. Security comes from Postgres row-level security (RLS) and grants, not from hiding code.

| File | Purpose |
|---|---|
| `index.html` | Home page, live counters from the database |
| `students.html` | Program search, application form, document upload, status tracker |
| `sponsors.html` | Pledge form and consented student profiles |
| `staff.html` | Staff portal (login required) |
| `config.js` | **The only file you edit**: Supabase URL and publishable key |
| `common.js` | Shared helpers and the Supabase client |
| `style.css` | Shared styles |
| `schema.sql` | Full database setup: tables, rules, grants, storage, sample data |

---

## Before you start

- A free account at [supabase.com](https://supabase.com)
- A text editor (VS Code is fine)
- Python 3 (only to preview locally) or any static file server
- Optional: a GitHub account and a Cloudflare Pages or Netlify account for deployment

---

## Setup

### 1. Create the Supabase project
1. Sign in to Supabase and create a new project.
2. Choose a **Mumbai (South Asia)** region so data stays in India. The region cannot be changed later.
3. Set a strong database password and save it in a password manager.
4. Wait until the project finishes setting up.

### 2. Create the database
1. Open **SQL Editor** and click **New query**.
2. Paste the whole of `schema.sql` and click **Run**. Run it once, on a fresh project.
3. You should see "Success". If it fails, nothing is created, so fix the error and run it again.

This creates the tables, security rules, grants, a private storage bucket (`application-docs`) and the sample data.

> **Important:** New Supabase projects no longer expose tables to the API automatically. `schema.sql` contains an explicit **GRANTS** section (4b). If you ever add a table, you must grant access to it too, or the pages will fail with `permission denied`.

### 3. Connect the pages to the database
1. In Supabase open **Project Settings**, then **API Keys** (or click **Connect**).
2. Copy the **Project URL** and the **Publishable key** (it starts with `sb_publishable_`; older projects may show an `anon` key, which also works).
3. Paste them into `config.js`:

```js
const LSF = {
  url: "https://YOUR-PROJECT.supabase.co",
  key: "YOUR-PUBLISHABLE-KEY"
};
```

Never put a **secret** or **service_role** key in any page or in GitHub.

### 4. Create the first staff login
1. In Supabase go to **Authentication → Users → Add user**. Enter an email and password and tick auto-confirm.
2. Copy the new user's **UUID**.
3. Run this in the SQL Editor with your UUID and name:

```sql
insert into staff (user_id, full_name, role)
values ('PASTE-USER-UUID-HERE', 'Your Name', 'admin');
```

4. Turn **off** public sign-ups (Authentication, then Sign In / Providers). Otherwise anyone can create an account.

Roles: `admin` (everything), `reviewer` (change application status), `finance` (log disbursements, view pledges).

### 5. Run it locally
In the project folder:

```bash
python -m http.server 8000
```

Open `http://localhost:8000`. Use a local server rather than double-clicking the files.

### 6. Test the whole flow

| Do this | Expect |
|---|---|
| Open the home page | Counters load (14 programs) |
| Open the Students page | 14 sample programs appear |
| Apply to a program with a small PDF or image | A tracking ID is shown |
| Enter the tracking ID in the tracker | Status "received" |
| Sign in to `staff.html` | The application appears; **Docs** opens the file |
| Change the status to approved, then Disburse | Tracker now says "disbursed" |
| Make a pledge on the Sponsors page | It appears in the staff Pledges tab |

### 7. Check data in the database
- **Table Editor:** open `applications`, `pledges`, `disbursements` and refresh.
- **Storage:** open the `application-docs` bucket; each application has a folder named with its tracking ID.
- **SQL Editor:**

```sql
select tracking_id, student_name, status, created_at
from applications order by created_at desc limit 5;
```

### 8. Deploy
Any static host works (Cloudflare Pages, Netlify). Upload or connect the repo, leave the build command empty, and publish the folder containing the HTML files. Confirm `yoursite/config.js` loads in the browser.

Keep `staff.html` unlinked from the public pages during the pilot. For a real launch, deploy it to its own subdomain (for example `staff.yourdomain.org`).

---

## Optional: GitHub integration with Supabase

The Supabase GitHub integration applies migrations from `supabase/migrations/` when you merge to your production branch. It does **not** host the website.

- Set **Working directory** to `.` if the `supabase/` folder is at the repo root, or to the subfolder that contains it.
- Put the schema in `supabase/migrations/<timestamp>_initial_schema.sql` (sections 1 to 5 of `schema.sql`) and the sample data in `supabase/seed.sql`.
- If you already ran `schema.sql` by hand, turn **Deploy to production** off, or the migration will fail on tables that already exist.
- Never commit a secret key, `.env` file or database password.

---

## Before real families use it

- [ ] Upgrade the database to Supabase Pro so it does not pause and has backups
- [ ] Require multi-factor sign-in for staff accounts
- [ ] Add a CAPTCHA (for example Cloudflare Turnstile) to the public forms
- [ ] Pin the Supabase script in each page to an exact version instead of `@2`
- [ ] Replace sample programs and profiles with real ones (`delete from programs;` and `delete from student_profiles;`, then add real data through the staff portal)
- [ ] Add student profiles only for students whose guardians gave written consent
- [ ] Have consent wording, privacy policy and DPDP Act obligations reviewed by a qualified advisor
- [ ] Open the Supabase account and hosting accounts in the NGO's name
- [ ] Add online payment (Razorpay) through a server-side step; pledges are currently records, not payments

---

## Troubleshooting

Press **F12**, open the **Console**, reload, and read the red error.

| Error or symptom | Cause and fix |
|---|---|
| "Could not load programs" | Run `console.log(LSF)` and `sb.from("programs").select("*").then(r => console.log(r))` in the console to see the real error |
| `permission denied for table ...` (42501) | Grants missing. Re-run section 4b of `schema.sql`, then `notify pgrst, 'reload schema';` |
| `relation ... does not exist` | `schema.sql` did not complete. Re-run it on a fresh project |
| `Invalid API key` | Wrong key in `config.js`. Use the publishable key, with no spaces |
| `Failed to fetch` | Wrong project URL, or the project is paused |
| `LSF is not defined` | `config.js` is missing, misnamed, or not in the same folder as the page |
| Still the placeholders after editing | Hard-reload with Ctrl+Shift+R |
| "This account does not have staff access" | The row in the `staff` table is missing or has the wrong UUID |
| Upload fails | File over 5 MB, wrong type (only PDF, JPG, PNG), or the storage section of `schema.sql` did not run |

Quick test without the page (replace both values):

```
https://YOUR-PROJECT.supabase.co/rest/v1/programs?select=name&apikey=YOUR-PUBLISHABLE-KEY
```

A list of names means the database and key work.

---

## Security notes

- The publishable key is public by design. The secret and `service_role` keys must never appear in the pages or the repo. If one leaks, rotate it straight away.
- Applications can only be created and checked through the `submit_application` and `track_application` functions. The public cannot read the `applications` table.
- Staff access is enforced by database rules and roles, not by the page. Hiding a button is not security.
- Every value shown in the staff portal is escaped, because strangers type into the public forms. Keep doing that for any field you add.

---

## Known limits of this prototype

- Pledges are recorded only; no money moves through the site.
- English only. Hindi and Marathi are planned.
- There is no audit log yet; adding one (database triggers) is the recommended next step for the real build.
- A MySQL version of the schema exists but needs a separate API server; this project uses Postgres on Supabase.
