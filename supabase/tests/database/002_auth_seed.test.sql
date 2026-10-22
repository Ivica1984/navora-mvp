-- T8: synthetic sign-in accounts exist locally and auth data is not exposed to anon.
begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

select is(
  (select count(*)::int from auth.users where email like '%@navora.test' and email_confirmed_at is not null),
  5,
  'five confirmed synthetic test users are seeded (admin.test added for ADM1)'
);

select is(
  (select count(*)::int from auth.users where email not like '%@navora.test'),
  0,
  'no non-test accounts in the seed'
);

select is(
  (select count(*)::int from auth.identities where provider = 'email'),
  5,
  'each test user has an email identity'
);

select ok(
  not has_table_privilege('anon', 'auth.users', 'select'),
  'anon has no SELECT privilege on auth.users'
);

select * from finish();
rollback;
