// Row types derived from the generated schema (T14). Feature types are built
// from these, so a migration that renames or drops a column breaks the build
// instead of failing at runtime.
import type { Database } from "./database.types";

type PublicTables = Database["public"]["Tables"];

export type TableRow<T extends keyof PublicTables> = PublicTables[T]["Row"];

/** Row without the tenant key: RLS already scopes every read (T9). */
export type TenantRow<T extends keyof PublicTables> = Omit<TableRow<T>, "organization_id">;
