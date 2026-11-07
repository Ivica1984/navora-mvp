// Inline error for a failed command (T15). Replaces alert(): announced to
// screen readers (role="alert"), does not block the page, and stays visible
// next to the control that failed.
export default function CommandError({ message }: { message: string | null }) {
  if (!message) return null;

  return (
    <div
      role="alert"
      data-testid="command-error"
      style={{
        background: "#FEF2F2",
        color: "#991B1B",
        border: "1px solid #FCA5A5",
        borderRadius: "12px",
        padding: "10px 12px",
        margin: "10px 0",
        fontSize: "14px",
        fontWeight: 600,
      }}
    >
      {message}
    </div>
  );
}
