// UX2-30 (3) (uxa UXR-58, ADR-135): the one error line of the /team screen. The team view, the assessment section and
// the care-plan review command render every refused command through it, so UX2-14 (one `ErrorLine` with the
// `error-inline` token on every screen) changes one place here. Its colour is unchanged until UX2-14.

export function ErrorText({ message, testId = "command-error" }: { message: string | null; testId?: string }) {
  if (!message) return null;
  return (
    <p role="alert" data-testid={testId} className="mt-2 rounded-lg border border-rose-300 bg-rose-50 p-2 text-sm font-semibold text-rose-800">
      {message}
    </p>
  );
}
