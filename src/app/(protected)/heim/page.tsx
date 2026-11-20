import Link from "next/link";
import { zurichToday } from "@/features/orders/queries";
import { getMyInstitutions, getPlan } from "@/features/home-plan/queries";
import {
  addStaff, addStation, assignStaff, loadExample, recordAbsence, removeAbsence, setShiftType, setStaffActive,
  setStaffingRule, unassignStaff,
} from "@/features/home-plan/commands";
import {
  EXAMPLE_NOTE, GRADE_CHOICES, HOME_PLAN_PATH, PLAN_VIEWS, WORKING_TIME_NOTE, addDays, assignableStaff, canPlan, canSettle,
  cellStatusText, dayLabel, daysBetween, gapsPerDay, gradeLabel, indexCells, isIsoDate, isWeekend, isoWeek, messageText,
  monthCode, monthLabel, personPlan, plannedHours, rangeFor, requirementText, weekdayShort, type Plan, type PlanCell,
  type PlanView,
} from "@/features/home-plan/rules";
import { PAGE_LABEL } from "@/lib/auth/nav";

// HD-1 / HD-2 (founder 2026-11-20; Blueprint §5.4 P4): the home plans its own staff. Week, month, plan per staff member
// and the home's own settings. Every status comes from `institution_plan` (one source); every write is a database
// function that checks the role again. Synthetic data only (Phase A). Fixed rules, no AI.
export default async function HomePlanPage({ searchParams }: PageProps<"/heim">) {
  const sp = await searchParams;
  const one = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);
  const asked: PlanView = PLAN_VIEWS.find((v) => v.key === one(sp.ansicht))?.key ?? "woche";
  const today = zurichToday();
  const date = isIsoDate(one(sp.datum)) ? (one(sp.datum) as string) : today;
  const person = one(sp.person);
  const message = messageText(one(sp.meldung));

  const institutions = await getMyInstitutions();
  if (institutions.length === 0) {
    return (
      <main className="mx-auto grid max-w-2xl gap-4 p-4">
        <h1 className="text-2xl font-bold">{PAGE_LABEL.heim}</h1>
        <p data-testid="heim-no-institution">Ihr Zugang ist keinem Heim zugeordnet.</p>
      </main>
    );
  }
  const inst = institutions[0];
  // Settings are the lead's (the database refuses the others anyway); nobody else is shown the forms.
  const view: PlanView = asked === "einstellungen" && !canSettle(inst.role) ? "woche" : asked;
  const { from, to } = rangeFor(view, date);
  const plan = await getPlan(inst.id, from, to);
  const href = (q: Record<string, string | undefined>) => {
    const params = new URLSearchParams();
    const merged = { ansicht: view, datum: date, person, ...q };
    for (const [k, v] of Object.entries(merged)) if (v) params.set(k, v);
    return `${HOME_PLAN_PATH}?${params.toString()}`;
  };
  const back = href({});

  return (
    <main className="mx-auto grid w-full max-w-7xl min-w-0 gap-4 p-4">
      <header className="grid gap-1">
        <h1 className="text-2xl font-bold">{PAGE_LABEL.heim}</h1>
        <p className="text-sm text-secondary" data-testid="heim-name">
          {inst.display_name}
          {inst.simulation ? " · Simulation, synthetische Daten" : ""}
        </p>
      </header>

      <nav aria-label="Ansicht" className="flex flex-wrap gap-2">
        {PLAN_VIEWS.filter((v) => v.key !== "einstellungen" || canSettle(inst.role)).map((v) => (
          <Link
            key={v.key}
            href={href({ ansicht: v.key })}
            aria-current={v.key === view ? "page" : undefined}
            className={`min-h-11 rounded-lg border px-3 py-2 text-sm font-semibold ${
              v.key === view ? "border-emerald-800 bg-emerald-800 text-white" : "border-stone-300 bg-white"
            }`}
          >
            {v.label}
          </Link>
        ))}
      </nav>

      {message && (
        <p
          role={message.kind === "error" ? "alert" : "status"}
          data-testid="heim-message"
          className={`rounded-lg border p-2 text-sm ${
            message.kind === "error" ? "border-rose-300 bg-rose-50 text-rose-800" : "border-emerald-900/20 bg-white text-emerald-900"
          }`}
        >
          {message.text}
        </p>
      )}

      {!plan ? (
        <p role="alert">Der Plan konnte nicht geladen werden.</p>
      ) : view !== "einstellungen" && (plan.stations.length === 0 || plan.shift_types.length === 0) ? (
        <EmptyHome plan={plan} back={back} weekStartDate={rangeFor("woche", today).from} settingsHref={href({ ansicht: "einstellungen" })} />
      ) : view === "woche" ? (
        <WeekView plan={plan} back={back} prev={href({ datum: addDays(from, -7) })} next={href({ datum: addDays(from, 7) })}
          todayHref={href({ datum: today })} />
      ) : view === "monat" ? (
        <MonthView plan={plan} prev={href({ datum: addDays(from, -1) })} next={href({ datum: addDays(to, 1) })}
          personHref={(id) => href({ ansicht: "personal", person: id })} />
      ) : view === "personal" ? (
        <StaffView plan={plan} back={back} person={person} personHref={(id) => href({ person: id })}
          prev={href({ datum: addDays(from, -1) })} next={href({ datum: addDays(to, 1) })} />
      ) : (
        <SettingsView plan={plan} back={back} />
      )}
    </main>
  );
}

const btn = "min-h-11 rounded-lg border border-stone-400 bg-white px-3 text-sm font-semibold";
const btnPrimary = "min-h-11 rounded-lg bg-emerald-800 px-3 text-sm font-semibold text-white";
const input = "min-h-11 rounded-lg border border-stone-300 bg-white px-2 text-sm";

function Hidden({ values }: { values: Record<string, string> }) {
  return (
    <>
      {Object.entries(values).map(([k, v]) => (
        <input key={k} type="hidden" name={k} value={v} />
      ))}
    </>
  );
}

function EmptyHome({ plan, back, weekStartDate, settingsHref }: { plan: Plan; back: string; weekStartDate: string; settingsHref: string }) {
  const lead = canSettle(plan.institution.role);
  return (
    <section className="grid gap-3 rounded-lg border border-stone-300 bg-white p-4" data-testid="heim-empty">
      <p className="font-semibold">Noch keine Stationen und Dienstarten erfasst.</p>
      {lead ? (
        <>
          <p className="text-sm">Legen Sie Stationen, Dienstarten und Ihre Mindestbesetzung unter «Einstellungen» an.</p>
          <Link href={settingsHref} className={`${btn} inline-grid w-fit place-items-center`}>Zu den Einstellungen</Link>
          {plan.institution.simulation && (
            <form action={loadExample} className="grid gap-2">
              <Hidden values={{ institution: plan.institution.id, week: weekStartDate, back }} />
              <p className="text-sm text-secondary">
                Oder für die Simulation: zwei Stationen, drei Dienstarten, acht synthetische Mitarbeitende und ein Wochenplan.
              </p>
              <button type="submit" className={`${btnPrimary} w-fit`} data-testid="heim-load-example">Beispieldaten laden</button>
            </form>
          )}
        </>
      ) : (
        <p className="text-sm">Die Heimleitung richtet den Plan ein.</p>
      )}
    </section>
  );
}

function PeriodNav({ title, prev, next, extra }: { title: string; prev: string; next: string; extra?: React.ReactNode }) {
  return (
    <div className="flex flex-wrap items-center gap-2">
      <Link href={prev} className={`${btn} grid place-items-center`} aria-label="Zurück">◀</Link>
      <p className="min-w-0 font-semibold" data-testid="heim-period">{title}</p>
      <Link href={next} className={`${btn} grid place-items-center`} aria-label="Weiter">▶</Link>
      {extra}
    </div>
  );
}

function statusClass(c: PlanCell): string {
  if (c.status === "gap") return "border-rose-300 bg-rose-50";
  if (c.status === "ok") return "border-emerald-900/20 bg-white";
  return "border-stone-200 bg-stone-50";
}

function WeekView({ plan, back, prev, next, todayHref }: { plan: Plan; back: string; prev: string; next: string; todayHref: string }) {
  const cells = indexCells(plan.cells);
  const days = daysBetween(plan.from, plan.to);
  const planner = canPlan(plan.institution.role);
  const gaps = plan.cells.filter((c) => c.status === "gap").length;
  return (
    <section aria-label="Wochenplan" className="grid gap-3">
      <PeriodNav
        title={`KW ${isoWeek(plan.from)} · ${dayLabel(plan.from)} bis ${dayLabel(plan.to)}`}
        prev={prev}
        next={next}
        extra={<Link href={todayHref} className={`${btn} grid place-items-center`}>Heute</Link>}
      />
      <p className="text-sm" data-testid="heim-week-gaps">
        {gaps === 0 ? "Keine Lücke in dieser Woche." : `${gaps} ${gaps === 1 ? "Dienst mit Lücke" : "Dienste mit Lücke"} in dieser Woche.`}
      </p>
      {planner && <p className="text-xs text-secondary">{WORKING_TIME_NOTE}</p>}
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {days.map((d) => (
          <article key={d} className={`grid content-start gap-2 rounded-lg border p-2 ${isWeekend(d) ? "border-stone-300 bg-stone-50" : "border-stone-200 bg-white"}`}
            data-testid="heim-day" data-date={d}>
            <h2 className="font-bold">{dayLabel(d)}</h2>
            {plan.stations.map((s) => (
              <div key={s.id} className="grid gap-1">
                <h3 className="text-sm font-semibold">{s.name}</h3>
                {plan.shift_types.map((t) => {
                  const c = cells.get(`${d}|${s.id}|${t.id}`);
                  if (!c) return null;
                  const free = planner ? assignableStaff(plan, d) : [];
                  return (
                    <div key={t.id} className={`grid gap-1 rounded-md border p-2 text-sm ${statusClass(c)}`}
                      data-testid="heim-cell" data-status={c.status} data-station={s.name} data-shift={t.code}>
                      <p className="flex flex-wrap justify-between gap-1">
                        <span className="font-semibold">{t.label} {t.starts_at}–{t.ends_at}</span>
                        <span data-testid="heim-cell-status" className={c.status === "gap" ? "font-semibold text-rose-800" : "text-secondary"}>
                          {cellStatusText(c)}
                        </span>
                      </p>
                      <p className="text-xs text-secondary">{requirementText(c)}{c.example ? ` · ${EXAMPLE_NOTE}` : ""}</p>
                      <ul className="grid gap-1">
                        {c.assigned.map((a) => (
                          <li key={a.assignment_id} className="flex flex-wrap items-center justify-between gap-1" data-testid="heim-assigned">
                            <span className={a.absent ? "line-through" : ""}>
                              {a.display_name} <span className="text-xs text-secondary">{gradeLabel(a.grade)}</span>
                              {a.absent && <span className="ml-1 text-xs font-semibold text-rose-800 no-underline">abwesend</span>}
                            </span>
                            {planner && (
                              <form action={unassignStaff}>
                                <Hidden values={{ assignment: a.assignment_id, back }} />
                                <button type="submit" className="min-h-11 px-2 text-xs underline" aria-label={`${a.display_name} entfernen`}>
                                  entfernen
                                </button>
                              </form>
                            )}
                          </li>
                        ))}
                      </ul>
                      {planner && free.length > 0 && (
                        <form action={assignStaff} className="flex flex-wrap gap-1">
                          <Hidden values={{ institution: plan.institution.id, station: s.id, shift: t.id, date: d, back }} />
                          <label className="sr-only" htmlFor={`a-${d}-${s.id}-${t.id}`}>Person für {t.label} {s.name} {dayLabel(d)}</label>
                          <select id={`a-${d}-${s.id}-${t.id}`} name="staff" className={`${input} min-w-0 flex-1`} data-testid="heim-assign-select">
                            {free.map((p) => (
                              <option key={p.id} value={p.id}>{p.display_name} ({gradeLabel(p.grade)})</option>
                            ))}
                          </select>
                          <button type="submit" className={btn} data-testid="heim-assign">Einteilen</button>
                        </form>
                      )}
                    </div>
                  );
                })}
              </div>
            ))}
          </article>
        ))}
      </div>
    </section>
  );
}

function MonthView({ plan, prev, next, personHref }: { plan: Plan; prev: string; next: string; personHref: (id: string) => string }) {
  const days = daysBetween(plan.from, plan.to);
  const gaps = gapsPerDay(plan);
  const people = plan.staff.filter((s) => s.active);
  return (
    <section aria-label="Monatsplan" className="grid gap-3">
      <PeriodNav title={monthLabel(plan.from)} prev={prev} next={next} />
      <p className="text-xs text-secondary">
        Kürzel je Tag: {plan.shift_types.map((t) => `${t.code} = ${t.label} ${t.starts_at}–${t.ends_at}`).join(" · ")} · A = abwesend
      </p>
      <div className="max-w-full overflow-x-auto rounded-lg border border-stone-200 bg-white">
        <table className="border-collapse text-xs" data-testid="heim-month">
          <thead>
            <tr>
              <th scope="col" className="sticky left-0 z-10 bg-white p-1 text-left">Person</th>
              {days.map((d) => (
                <th key={d} scope="col" className={`min-w-8 p-1 text-center font-semibold ${isWeekend(d) ? "bg-stone-100" : ""}`}>
                  {weekdayShort(d)}<br />{Number(d.slice(8))}
                </th>
              ))}
              <th scope="col" className="p-1 text-right">Std.</th>
            </tr>
          </thead>
          <tbody>
            {people.map((p) => {
              const pp = personPlan(plan, p.id);
              return (
                <tr key={p.id} className="border-t border-stone-200" data-testid="heim-month-row">
                  <th scope="row" className="sticky left-0 z-10 whitespace-nowrap bg-white p-1 text-left font-normal">
                    <Link href={personHref(p.id)} className="underline">{p.display_name}</Link>{" "}
                    <span className="text-secondary">{gradeLabel(p.grade)}</span>
                  </th>
                  {pp.map((day) => (
                    <td key={day.date} className={`p-1 text-center ${day.absent ? "bg-amber-50 font-semibold text-amber-900" : isWeekend(day.date) ? "bg-stone-50" : ""}`}>
                      {monthCode(day)}
                    </td>
                  ))}
                  <td className="p-1 text-right">{plannedHours(plan, p.id)}</td>
                </tr>
              );
            })}
            <tr className="border-t-2 border-stone-300">
              <th scope="row" className="sticky left-0 z-10 bg-white p-1 text-left">Lücken</th>
              {days.map((d) => (
                <td key={d} className={`p-1 text-center font-semibold ${(gaps.get(d) ?? 0) > 0 ? "bg-rose-50 text-rose-800" : "text-secondary"}`}
                  data-testid="heim-month-gaps" data-date={d}>
                  {gaps.get(d) ?? 0}
                </td>
              ))}
              <td />
            </tr>
          </tbody>
        </table>
      </div>
      <p className="text-xs text-secondary">Stunden = Dienstlänge laut Ihren Dienstarten, ohne Pausenabzug; Abwesenheiten zählen nicht.</p>
    </section>
  );
}

function StaffView({ plan, back, person, personHref, prev, next }: {
  plan: Plan; back: string; person: string | undefined; personHref: (id: string) => string; prev: string; next: string;
}) {
  const planner = canPlan(plan.institution.role);
  const selected = plan.staff.find((s) => s.id === person) ?? null;
  const station = new Map(plan.stations.map((s) => [s.id, s.name]));
  return (
    <section aria-label="Mitarbeitende" className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
      <div className="grid content-start gap-3">
        <h2 className="text-lg font-bold">Mitarbeitende ({plan.staff.length})</h2>
        <ul className="grid gap-1" data-testid="heim-staff-list">
          {plan.staff.map((s) => (
            <li key={s.id} className={`flex flex-wrap items-center justify-between gap-2 rounded-lg border p-2 text-sm ${s.id === person ? "border-emerald-800 bg-white" : "border-stone-200 bg-white"}`}>
              <Link href={personHref(s.id)} className={`underline ${s.active ? "" : "text-secondary"}`} data-testid="heim-staff-link">
                {s.display_name}
              </Link>
              <span className="text-xs text-secondary">
                {gradeLabel(s.grade)}{s.home_station_id ? ` · ${station.get(s.home_station_id) ?? ""}` : ""}{s.active ? "" : " · nicht aktiv"}
              </span>
            </li>
          ))}
        </ul>
        {planner && (
          <form action={addStaff} className="grid gap-2 rounded-lg border border-stone-300 bg-white p-3" data-testid="heim-add-staff">
            <h3 className="font-semibold">Person hinzufügen</h3>
            <Hidden values={{ institution: plan.institution.id, back }} />
            <label className="grid gap-1 text-sm">Name (synthetisch)
              <input name="name" required minLength={2} maxLength={80} className={input} />
            </label>
            <label className="grid gap-1 text-sm">Stufe
              <select name="grade" className={input}>
                {GRADE_CHOICES.map((g) => <option key={g.value} value={g.value}>{g.label}</option>)}
              </select>
            </label>
            <label className="grid gap-1 text-sm">Stammstation
              <select name="station" className={input}>
                <option value="">keine</option>
                {plan.stations.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </label>
            <button type="submit" className={`${btnPrimary} w-fit`}>Hinzufügen</button>
          </form>
        )}
      </div>

      <div className="grid content-start gap-3">
        {!selected ? (
          <p className="text-sm">Wählen Sie eine Person, um ihren Monatsplan zu sehen.</p>
        ) : (
          <PersonPanel plan={plan} staff={selected} back={back} planner={planner} prev={prev} next={next} />
        )}
      </div>
    </section>
  );
}

function PersonPanel({ plan, staff, back, planner, prev, next }: {
  plan: Plan; staff: Plan["staff"][number]; back: string; planner: boolean; prev: string; next: string;
}) {
  const days = personPlan(plan, staff.id);
  const absences = plan.absences.filter((a) => a.staff_id === staff.id);
  const worked = days.filter((d) => d.shifts.length > 0 && !d.absent).length;
  return (
    <div className="grid gap-3" data-testid="heim-person">
      <h2 className="text-lg font-bold">{staff.display_name} <span className="text-sm font-normal text-secondary">{gradeLabel(staff.grade)}</span></h2>
      <PeriodNav title={monthLabel(plan.from)} prev={prev} next={next} />
      <p className="text-sm" data-testid="heim-person-summary">
        {worked} Diensttage · {plannedHours(plan, staff.id)} Std. geplant · {days.filter((d) => d.absent).length} Tage abwesend
      </p>
      {planner && (
        <div className="flex flex-wrap gap-2">
          <form action={recordAbsence} className="flex flex-wrap items-end gap-2 rounded-lg border border-stone-300 bg-white p-2" data-testid="heim-absence-form">
            <Hidden values={{ institution: plan.institution.id, staff: staff.id, back }} />
            <label className="grid gap-1 text-sm">Abwesend von
              <input type="date" name="from" required className={input} />
            </label>
            <label className="grid gap-1 text-sm">bis
              <input type="date" name="to" className={input} />
            </label>
            <button type="submit" className={btn}>Abwesenheit erfassen</button>
            <p className="w-full text-xs text-secondary">Ohne Grund: NAVORA fragt und speichert keinen Abwesenheitsgrund.</p>
          </form>
          <form action={setStaffActive}>
            <Hidden values={{ staff: staff.id, active: staff.active ? "false" : "true", back }} />
            <button type="submit" className={btn}>{staff.active ? "Nicht mehr aktiv" : "Wieder aktiv"}</button>
          </form>
        </div>
      )}
      {absences.length > 0 && (
        <ul className="grid gap-1 text-sm" data-testid="heim-absences">
          {absences.map((a) => (
            <li key={a.id} className="flex flex-wrap items-center gap-2 rounded-lg border border-amber-400 bg-amber-50 p-2">
              <span>Abwesend {dayLabel(a.starts_on)}{a.ends_on !== a.starts_on ? ` bis ${dayLabel(a.ends_on)}` : ""}</span>
              {planner && (
                <form action={removeAbsence}>
                  <Hidden values={{ absence: a.id, back }} />
                  <button type="submit" className="min-h-11 px-2 text-xs underline">entfernen</button>
                </form>
              )}
            </li>
          ))}
        </ul>
      )}
      <ol className="grid gap-1 text-sm" data-testid="heim-person-days">
        {days.map((d) => (
          <li key={d.date} className={`flex flex-wrap gap-2 rounded-md border p-2 ${d.absent ? "border-amber-400 bg-amber-50" : d.shifts.length ? "border-stone-200 bg-white" : "border-stone-100 bg-stone-50 text-secondary"}`}
            data-testid="heim-person-day" data-date={d.date}>
            <span className="w-20 font-semibold">{dayLabel(d.date)}</span>
            {d.absent && <span className="font-semibold text-amber-900">abwesend</span>}
            {d.shifts.map((s) => (
              <span key={s.assignment_id}>{s.label} {s.time} · {s.station}</span>
            ))}
            {!d.absent && d.shifts.length === 0 && <span>frei</span>}
          </li>
        ))}
      </ol>
    </div>
  );
}

function SettingsView({ plan, back }: { plan: Plan; back: string }) {
  const cells = indexCells(plan.cells);
  return (
    <section aria-label="Einstellungen" className="grid gap-4 lg:grid-cols-2">
      <div className="grid content-start gap-3 rounded-lg border border-stone-300 bg-white p-3">
        <h2 className="text-lg font-bold">Stationen</h2>
        <ul className="grid gap-1 text-sm">{plan.stations.map((s) => <li key={s.id}>{s.name}</li>)}</ul>
        <form action={addStation} className="flex flex-wrap gap-2">
          <Hidden values={{ institution: plan.institution.id, back }} />
          <label className="sr-only" htmlFor="station-name">Neue Station</label>
          <input id="station-name" name="name" required maxLength={60} placeholder="Neue Station" className={`${input} min-w-0 flex-1`} />
          <button type="submit" className={btn}>Hinzufügen</button>
        </form>
      </div>
      <div className="grid content-start gap-3 rounded-lg border border-stone-300 bg-white p-3">
        <h2 className="text-lg font-bold">Dienstarten</h2>
        <ul className="grid gap-1 text-sm">
          {plan.shift_types.map((t) => <li key={t.id}>{t.code} · {t.label} {t.starts_at}–{t.ends_at}</li>)}
        </ul>
        <form action={setShiftType} className="flex flex-wrap items-end gap-2">
          <Hidden values={{ institution: plan.institution.id, back }} />
          <label className="grid gap-1 text-sm">Kürzel<input name="code" required maxLength={12} className={`${input} w-16`} /></label>
          <label className="grid gap-1 text-sm">Name<input name="label" required maxLength={40} className={`${input} w-28`} /></label>
          <label className="grid gap-1 text-sm">von<input type="time" name="starts" required className={input} /></label>
          <label className="grid gap-1 text-sm">bis<input type="time" name="ends" required className={input} /></label>
          <button type="submit" className={btn}>Speichern</button>
        </form>
        <p className="text-xs text-secondary">Gleiches Kürzel überschreibt die Dienstart. Endet ein Dienst vor seinem Beginn, endet er am Folgetag.</p>
      </div>
      <div className="grid content-start gap-3 rounded-lg border border-stone-300 bg-white p-3 lg:col-span-2">
        <h2 className="text-lg font-bold">Mindestbesetzung (Ihre Vorgabe)</h2>
        <p className="text-xs text-secondary">
          Die Mindestbesetzung legt das Heim fest. NAVORA gibt keinen Personalschlüssel vor und prüft nur, ob Ihre Vorgabe
          im Plan erfüllt ist.
        </p>
        <div className="grid gap-2 md:grid-cols-2">
          {plan.stations.flatMap((s) =>
            plan.shift_types.map((t) => {
              const c = cells.get(`${plan.from}|${s.id}|${t.id}`);
              return (
                <form key={`${s.id}-${t.id}`} action={setStaffingRule} className="flex flex-wrap items-end gap-2 rounded-md border border-stone-200 p-2"
                  data-testid="heim-rule-form">
                  <Hidden values={{ institution: plan.institution.id, station: s.id, shift: t.id, back }} />
                  <p className="w-full text-sm font-semibold">{s.name} · {t.label} <span className="font-normal text-secondary">({c ? requirementText(c) : "keine Vorgabe"}{c?.example ? `, ${EXAMPLE_NOTE}` : ""})</span></p>
                  <label className="grid gap-1 text-sm">Personen
                    <input type="number" name="total" min={0} max={50} required defaultValue={c?.required_total ?? ""} className={`${input} w-20`} />
                  </label>
                  <label className="grid gap-1 text-sm">davon mindestens
                    <input type="number" name="gradeCount" min={0} max={50} defaultValue={c?.required_grade_count ?? 0} className={`${input} w-20`} />
                  </label>
                  <label className="grid gap-1 text-sm">Stufe
                    <select name="grade" defaultValue={c?.required_grade ?? ""} className={input}>
                      <option value="">–</option>
                      {GRADE_CHOICES.map((g) => <option key={g.value} value={g.value}>{g.label}</option>)}
                    </select>
                  </label>
                  <button type="submit" className={btn}>Speichern</button>
                </form>
              );
            }),
          )}
        </div>
      </div>
    </section>
  );
}
