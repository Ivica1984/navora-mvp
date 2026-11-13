import { getClientOrderPage } from "@/features/orders/queries";
import { coverStateText, radiusLine, shiftLabelLine } from "@/features/orders/rules";
import OrderForm from "./order-form";

// BK-a (brief docs/agents/briefs/BK.md; ADR-194): the client's order page (Auftraggeber-Ansicht). Synthetic data only
// (Phase A). The form writes nothing; «Bestätigen & Absenden» is the only write, checked again by the database.
export default async function OrderPage() {
  const data = await getClientOrderPage();
  if (data.accounts.length === 0) {
    return (
      <main className="mx-auto grid max-w-2xl gap-4 p-4">
        <h1 className="text-2xl font-bold">Auftrag erfassen</h1>
        <p data-testid="order-no-account">Ihr Zugang ist keinem Auftraggeber-Konto zugeordnet.</p>
      </main>
    );
  }
  const account = data.accounts[0];
  return (
    <main className="mx-auto grid w-full max-w-2xl min-w-0 gap-6 p-4">
      <header className="grid gap-1">
        <h1 className="text-2xl font-bold">Auftrag erfassen</h1>
        <p className="text-sm text-secondary">{account.display_name} · synthetische Daten</p>
      </header>
      <OrderForm
        accountId={account.id}
        today={data.today}
        postcodes={data.postcodes}
        activities={data.activities}
      />
      <section aria-label="Ihre Aufträge" className="grid gap-2">
        <h2 className="text-lg font-bold">Ihre Aufträge ({data.orders.length})</h2>
        {data.orders.length === 0 && <p className="text-sm text-secondary">Noch kein Auftrag bestätigt.</p>}
        <ul className="grid gap-2" data-testid="client-orders">
          {data.orders.map((o) => (
            <li key={o.id} className="grid gap-1 rounded-lg border border-stone-200 bg-white p-3 text-sm">
              <p className="break-words font-semibold">{o.sentence}</p>
              {shiftLabelLine(o.shift_label) && <p>{shiftLabelLine(o.shift_label)}</p>}
              <p>{radiusLine(o.radius_km)}</p>
              <p data-testid="order-cover-state" className="font-semibold">Stand: {coverStateText(o.cover_state)}</p>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
