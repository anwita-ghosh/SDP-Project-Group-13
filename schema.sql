-- ============ LOKSEWA PORTAL: COMPLETE DATABASE SETUP ============
-- Paste this whole file into Supabase -> SQL Editor -> Run. Run it once on a fresh project.

-- 1. TABLES
create table programs (
  id bigint generated always as identity primary key,
  name text not null, stages text[] not null, category text not null,
  circumstances text[] not null default '{}', amount text, deadline text, description text,
  active boolean not null default true);

create table applications (
  id bigint generated always as identity primary key,
  tracking_id text unique not null default 'LSF-' || upper(substr(md5(random()::text),1,6)),
  program_id bigint references programs(id),
  student_name text not null check (char_length(student_name) <= 100),
  guardian_contact text not null check (char_length(guardian_contact) <= 100),
  state text, need text check (char_length(need) <= 1000),
  status text not null default 'received'
    check (status in ('received','under_review','approved','rejected','disbursed')),
  created_at timestamptz not null default now());

create table pledges (
  id bigint generated always as identity primary key,
  donor_name text not null check (char_length(donor_name) <= 100),
  email text not null check (char_length(email) <= 150),
  amount numeric not null check (amount >= 100),
  mode text not null check (mode in ('once','monthly')),
  target text check (char_length(target) <= 200),
  created_at timestamptz not null default now());

create table student_profiles (            -- shown publicly; only consented, first-name-only profiles
  id bigint generated always as identity primary key,
  first_name text not null, age int, stage text, need text, story text,
  goal numeric not null default 0, raised numeric not null default 0,
  consented boolean not null default false);

create table staff (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text, role text not null check (role in ('admin','reviewer','finance')));

create table disbursements (
  id bigint generated always as identity primary key,
  application_id bigint not null references applications(id),
  amount numeric not null check (amount > 0), payee text not null,
  created_by uuid default auth.uid(), created_at timestamptz not null default now());

-- 2. LOCK EVERYTHING DOWN (row-level security)
alter table programs enable row level security;
alter table applications enable row level security;
alter table pledges enable row level security;
alter table student_profiles enable row level security;
alter table staff enable row level security;
alter table disbursements enable row level security;

-- 3. HELPER FUNCTIONS
create function staff_role() returns text language sql stable security definer set search_path = public as
$$ select role from staff where user_id = auth.uid() $$;

create function submit_application(p_program bigint, p_name text, p_contact text, p_state text, p_need text)
returns text language sql security definer set search_path = public as
$$ insert into applications(program_id, student_name, guardian_contact, state, need)
   values (p_program, p_name, p_contact, p_state, p_need) returning tracking_id $$;

create function track_application(tid text) returns text language sql security definer set search_path = public as
$$ select status from applications where tracking_id = upper(tid) $$;

create function set_application_status(p_id bigint, p_status text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if staff_role() is null then raise exception 'not allowed'; end if;
  if p_status = 'disbursed' and staff_role() not in ('admin','finance') then raise exception 'not allowed'; end if;
  if p_status <> 'disbursed' and staff_role() not in ('admin','reviewer') then raise exception 'not allowed'; end if;
  update applications set status = p_status where id = p_id;
end $$;

create function public_stats() returns json language sql stable security definer set search_path = public as
$$ select json_build_object(
     'students', (select count(*) from applications where status = 'disbursed'),
     'programs', (select count(*) from programs where active),
     'sponsors', (select count(distinct lower(email)) from pledges)) $$;

grant execute on function submit_application, track_application, public_stats to anon, authenticated;
grant execute on function staff_role, set_application_status to authenticated;

-- 4. WHO CAN DO WHAT
create policy "public reads active programs" on programs for select using (active);
create policy "staff read all programs" on programs for select to authenticated using (staff_role() is not null);
create policy "admin manages programs" on programs for all to authenticated using (staff_role() = 'admin') with check (staff_role() = 'admin');

create policy "public reads consented profiles" on student_profiles for select using (consented);
create policy "admin manages profiles" on student_profiles for all to authenticated using (staff_role() = 'admin') with check (staff_role() = 'admin');

create policy "public creates pledges" on pledges for insert to anon, authenticated with check (amount >= 100);
create policy "finance reads pledges" on pledges for select to authenticated using (staff_role() in ('admin','finance'));

create policy "staff read applications" on applications for select to authenticated using (staff_role() is not null);
-- (the public never touches applications directly: only submit_application / track_application)

create policy "finance reads disbursements" on disbursements for select to authenticated using (staff_role() in ('admin','finance'));
create policy "finance logs disbursements" on disbursements for insert to authenticated with check (staff_role() in ('admin','finance'));

create policy "staff read own record" on staff for select to authenticated using (user_id = auth.uid());

-- 4b. GRANTS (required on new Supabase projects: tables are no longer exposed to the API by default)
grant select on programs, student_profiles to anon;
grant insert on pledges to anon;
grant select, insert, update, delete on programs, student_profiles to authenticated;
grant select, insert on pledges to authenticated;
grant select on applications, staff to authenticated;
grant select, insert on disbursements to authenticated;

-- 5. PRIVATE FILE STORAGE FOR APPLICATION DOCUMENTS
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('application-docs','application-docs', false, 5242880, array['application/pdf','image/jpeg','image/png'])
on conflict (id) do nothing;
create policy "anyone uploads application docs" on storage.objects for insert to anon, authenticated with check (bucket_id = 'application-docs');
create policy "staff read application docs" on storage.objects for select to authenticated using (bucket_id = 'application-docs' and staff_role() is not null);

-- 6. SAMPLE DATA (fictional: delete or replace with Loksewa's real programs)
insert into programs (name, stages, category, circumstances, amount, deadline, description) values
('Little Sprouts Fee Support','{Kindergarten}','Fee waiver','{"Low income"}','₹12,000/yr','30 Nov','Covers pre-school fees at partner centres for children from low-income households.'),
('First Steps Kit','{Kindergarten,Primary}','Books & supplies','{"Low income","Orphan / single parent"}','₹3,000','15 Dec','Uniform, bag, books and stationery for a full school year.'),
('Bright Girls Primary Grant','{Primary}','Scholarship','{"Girl child"}','₹8,000/yr','10 Jan','Annual grant to keep girls in school through Class 5.'),
('Sponsor-a-Child Circle','{Primary,Secondary}','Sponsorship','{"Low income","Orphan / single parent"}','₹20,000/yr','Rolling','Matched with a personal sponsor; includes mentor check-ins and updates.'),
('Widow''s Child Education Aid','{Primary,Secondary,"Higher Secondary"}','Scholarship','{"Widow''s child","Low income"}','₹18,000/yr','20 Jan','Fee and supplies support for children raised by widowed mothers.'),
('Inclusive Learning Aid','{Primary,Secondary,"Higher Secondary"}','Books & supplies','{"Disability"}','₹25,000','20 Dec','Assistive devices and learning materials for students with disabilities.'),
('Secondary Merit Award','{Secondary}','Scholarship','{"Merit"}','₹15,000/yr','05 Jan','For students scoring 85%+ in Class 8 with family income below ₹4L.'),
('Science Stream Booster','{"Higher Secondary"}','Scholarship','{"Merit","Low income"}','₹30,000/yr','28 Feb','Supports Class 11–12 science students including coaching and lab costs.'),
('First-Generation Graduate Fund','{Undergraduate}','Scholarship','{"Low income"}','₹60,000/yr','31 Jan','For students who are first in their family to attend college.'),
('Women in STEM Scholarship','{Undergraduate,Postgraduate}','Scholarship','{"Girl child","Merit"}','₹90,000/yr','15 Feb','Full tuition support for women in engineering, science and tech programmes.'),
('Campus Living Sponsorship','{Undergraduate}','Sponsorship','{"Low income","Orphan / single parent"}','₹40,000/yr','Rolling','Hostel and meal support paired with an individual sponsor.'),
('Postgraduate Excellence Grant','{Postgraduate}','Scholarship','{"Merit"}','₹1,20,000','10 Mar','One-time grant for high-achieving master''s students.'),
('Research Bridge Fellowship','{PhD}','Scholarship','{"Merit"}','₹2,40,000/yr','30 Apr','Stipend and contingency support for doctoral researchers.'),
('Accessible Higher Ed Fund','{Undergraduate,Postgraduate,PhD}','Fee waiver','{"Disability"}','Up to 100% fees','Rolling','Tuition waiver plus accessibility support at partner universities.');

insert into student_profiles (first_name, age, stage, need, story, goal, raised, consented) values
('Aarav',9,'Primary','Annual fees and supplies','Lives with his mother, who works as a domestic helper. Loves maths and wants to be a pilot.',20000,14500,true),
('Meera',15,'Secondary','Fees and a bicycle to reach school','Top of her class, but the school is 6 km away. A bicycle and fees would keep her enrolled.',24000,9000,true),
('Sana',19,'Undergraduate','Tuition and hostel','First in her family at college, studying computer science on a partial merit seat.',60000,41000,true),
('Rohit',24,'Postgraduate','Master''s tuition','Working part-time while completing an MSW to serve rural communities.',90000,22000,true);

-- 7. AFTER THE FIRST ADMIN EXISTS (see tutorial step 4), run this with their user id:
-- insert into staff (user_id, full_name, role) values ('PASTE-USER-UUID-HERE', 'Your Name', 'admin');
