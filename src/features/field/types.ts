import type { Database } from "@/lib/supabase/database.types";

/** One row of public.field_visits() — generated from the migration (T14). */
export type FieldVisit = Database["public"]["Functions"]["field_visits"]["Returns"][number];
