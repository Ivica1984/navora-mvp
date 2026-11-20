import { describe, expect, it } from "vitest";
import { findTextPatches, CUTOFF } from "../../scripts/no-text-patch.mjs";
import { missingRequired, parseFile, qualifiedName, renderFile, renderGuardTest } from "../../scripts/fn-source.mjs";

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
    expect(missingRequired([{ name: "public.f", required: ["LEAVE1-3"] }], [{ name: "public.f", signature: "public.f(uuid)", definition: "begin end" }])).toEqual([
      "public.f(uuid): lost required «LEAVE1-3»",
    ]);
  });
});

describe("STAB1 (d) permission and guard snapshot", () => {
  const file = renderFile("public.f", [
    {
      signature: "public.f(p_id uuid)",
      definition: "CREATE OR REPLACE FUNCTION public.f(p_id uuid)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO ''\nAS $function$ begin perform private.access_ended(p_id); end $function$\n",
      acl_set: true,
      grantees: ["authenticated"],
      comment: null,
    },
  ]);
  it("reads signature, security properties and grantees from the committed file", () => {
    expect(parseFile("public.f", file)).toEqual([
      { name: "public.f", args: "p_id uuid", signature: "public.f(p_id uuid)", definer: true, emptySearchPath: true, grantees: ["authenticated"] },
    ]);
  });
  it("asserts every property, each app role and each required guard", () => {
    const sql = renderGuardTest([{ name: "public.f", required: ["access_ended"] }], new Map([["public.f.sql", file]]));
    expect(sql).toContain("select plan(8);");
    expect(sql).toContain("'public.f(p_id uuid): execute for anon refused'");
    expect(sql).toContain("'public.f(p_id uuid): execute for authenticated granted'");
    expect(sql).toContain("'public.f(p_id uuid): execute for service_role refused'");
    expect(sql).toContain("'public.f(p_id uuid): no execute for PUBLIC'");
    expect(sql).toContain("'public.f(p_id uuid): keeps «access_ended»'");
    expect(sql).toContain("pg_get_function_identity_arguments(p.oid) = 'p_id uuid'");
  });
  it("refuses a file without the explicit revoke (default PUBLIC execute)", () => {
    const open = file.replace(/^revoke all .*$/m, "");
    expect(() => parseFile("public.f", open)).toThrow(/default PUBLIC execute is refused/);
  });
  it("refuses a file whose signature line names another function", () => {
    expect(() => parseFile("public.g", file)).toThrow(/signature line names public.f/);
  });
});
