-- PROBE ONLY (STAB1 negative test (ii)), never merged: a text patch on a listed function. no-text-patch must be red.
do $$
declare d text := pg_get_functiondef('private.order_take_visit'::regproc);
begin
  execute replace(d, 'AS $function$', 'AS $function$ ');
end $$;
