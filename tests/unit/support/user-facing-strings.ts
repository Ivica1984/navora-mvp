import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import ts from "typescript";

// UX1-11 / UX1-13 (ADR-108): the user-facing strings of a source file, read from its syntax tree.
// Code comments are not part of the tree's literals, so they are exempt without a regex.
// Not user-facing (skipped): module specifiers, directives ("use client"), and the values of JSX attributes that never
// reach the reader (class names, test ids, routes, ids, form names). `data-ref` is the reviewer reference: its value is
// exempt by design (UX1-11 "an element or attribute marked for reviewers").

const NOT_USER_FACING_ATTRIBUTES = new Set([
  "className", "style", "data-testid", "data-ref", "href", "id", "key", "type", "name", "htmlFor", "role",
  "method", "action", "autoComplete", "inputMode", "pattern", "target", "rel", "src", "form", "lang",
  "aria-labelledby", "aria-describedby", "aria-controls",
]);

export type UserString = { file: string; line: number; text: string };

export function sourceFiles(dir: string): string[] {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) return sourceFiles(path);
    return /\.(tsx|ts)$/.test(name) && !/\.test\.tsx?$/.test(name) ? [path] : [];
  });
}

function skipped(node: ts.Node): boolean {
  for (let n: ts.Node | undefined = node.parent; n; n = n.parent) {
    if (ts.isImportDeclaration(n) || ts.isExportDeclaration(n) || ts.isExternalModuleReference(n)) return true;
    if (ts.isJsxAttribute(n)) return NOT_USER_FACING_ATTRIBUTES.has(n.name.getText());
    if (ts.isJsxElement(n) || ts.isJsxSelfClosingElement(n) || ts.isStatement(n)) break;
  }
  if (ts.isExpressionStatement(node.parent) && ts.isStringLiteral(node)) return true; // directive
  return false;
}

export function userFacingStrings(file: string): UserString[] {
  const source = readFileSync(file, "utf8");
  const tree = ts.createSourceFile(file, source, ts.ScriptTarget.Latest, true, file.endsWith(".tsx") ? ts.ScriptKind.TSX : ts.ScriptKind.TS);
  const out: UserString[] = [];
  const push = (node: ts.Node, text: string) => {
    if (!text.trim() || skipped(node)) return;
    out.push({ file, line: tree.getLineAndCharacterOfPosition(node.getStart()).line + 1, text: text.replace(/\s+/g, " ").trim() });
  };
  const visit = (node: ts.Node) => {
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) push(node, node.text);
    else if (ts.isTemplateExpression(node)) {
      push(node, [node.head.text, ...node.templateSpans.map((s) => s.literal.text)].join(" "));
    } else if (ts.isJsxText(node)) push(node, node.text);
    ts.forEachChild(node, visit);
  };
  visit(tree);
  return out;
}
