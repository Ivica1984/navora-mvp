import { describe, expect, it } from "vitest";
import { findTextPatches, CUTOFF } from "../../scripts/no-text-patch.mjs";
import { missingRequired, qualifiedName, renderFile } from "../../scripts/fn-source.mjs";

describe("STAB-1 no text patch after the cutoff", () => {
  it("refuses a new migration that patches a function by text", () => {
    const after = "29991231000000_x.sql";
    expect(findTextPatches([{ name: after, content: "select private.bk_f_patch('public.f(uuid)', array[]);" }])).toHaveLength(1);
    expect(findTextPatches([{ name: after, content: "def text := pg_get_functiondef(p_fn::regprocedure);" }])).toHaveLength(1);
  });
  it("accepts a whole-file re-creation and leaves history alone", () => {
    const after = "29991231000000_x.sql";
    expect(findTextPatches([{ name: after, content: "create or replace function public.f() returns int language sql as $$ select 1 $$;" }])).toEqual([]);
    expect(findTextPatches([{ name: `${CUTOFF}_old.sql`, content: "select private.x_patch('a', array[]);" }])).toEqual([]);
  });
});

describe("STAB-1 function source files", () => {
  it("names the file after the qualified function", () => {
    expect(qualifiedName("private.screen_order_reach(uuid, integer)")).toBe("private.screen_order_reach");
  });
  it("renders the whole definition, the grants and the comment", () => {
    const text = renderFile("public.f", [
      { signature: "public.f(uuid)", definition: "CREATE OR REPLACE FUNCTION public.f(uuid)\n AS $$ select 1 $$\n", acl_set: true, grantees: ["authenticated"], comment: "it's x" },
    ]);
    expect(text).toContain("CREATE OR REPLACE FUNCTION public.f(uuid)\n AS $$ select 1 $$;");
    expect(text).toContain("revoke all on function public.f(uuid) from public, anon, authenticated, service_role;");
    expect(text).toContain("grant execute on function public.f(uuid) to authenticated;");
    expect(text).toContain("comment on function public.f(uuid) is 'it''s x';");
  });
  it("reports a lost required property", () => {
    expect(missingRequired([{ signature: "public.f(uuid)", required: ["LEAVE1-3"] }], [{ definition: "begin end" }])).toEqual([
      "public.f(uuid): lost required «LEAVE1-3»",
    ]);
  });
});
