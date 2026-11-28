import Link from "next/link";
import { zurichToday } from "@/features/orders/queries";
import { getDraftPlan, getDraftRunRefusals, getMyInstitutions, newApplyId, getOrderChoices, getPlan, previewGapOrder } from "@/features/home-plan/queries";
import { DRAFT_MARK, WORKING_TIME_LAW_MARK, gapReasonText, unmetWishReasonText } from "@/features/home-plan/draft";
import { draftInputFromPlan, draftPeriodRange, rowsFormValue, sortGaps, sortRows, timedDraft, type DraftPeriod } from "@/features/home-plan/draft-screen";
import {
  addStaff, addStation, applyDraft, assignStaff, checkGapOrder, discardGapOrder, loadExample, withdrawGapOrder, prepareGapOrder, recordAbsence, removeAbsence, sendGapOrder,
  setMonthlyTarget, setMonthlyTargetThreshold, setPlanningLimits, setShiftClass, setShiftType, setSplitShiftType, setStaffActive,
  setStaffPlanning, setStaffingRule, setWorkDaysPerWeek, unassignStaff,
} from "@/features/home-plan/commands";
import { dailyTargetHint, dailyTargetText, isSplit, shiftTimesText } from "@/features/home-plan/split";
import {
  LIMIT_MARK, NOT_ENTERED, NO_CLASS, NO_VALUE, SELECTABLE_SHIFT_CLASSES, SHIFT_CLASS_LABEL, SHIFT_MODEL_LABEL, minutesAsHours, shiftClassLabel,
  shiftModelLabel, shownValue,
} from "@/features/home-plan/planning-inputs";
import { SHIFT_MODELS, shiftMinutes } from "@/features/home-plan/draft";
import {
  ABSENCE_KINDS, APPLY_RUN_CODES, EXAMPLE_NOTE, GRADE_CHOICES, HOME_PLAN_PATH, PLAN_VIEWS, WORKING_TIME_NOTE, absenceKindLabel, addDays, assignableStaff, canPlan, canPrepareOrder,
  canSettle, canWithdrawOrder, cellOfDraft, cellStatusText, orderLine, orderSendSummary, ordersPerDay, tagList, dayLabel, daysBetween, gapsPerDay, gradeLabel, indexCells, isIsoDate, isWeekend, isoWeek, messageText,
  hoursUnknownCount, hoursUnknownCountText, hoursUnknownNext, withoutPensumAndTarget, monthCode, monthLabel, monthPeople, monthTargetOf, parseApplyRun, parseCount, pensumMissingPersons, pensumMissingText, parseWarning, personPlan, plannedHours, rangeFor, requirementText, ruleText, ruleWarning, weekdayShort, type Plan, type PlanCell,
  type PendingWarning, type MonthTarget,
  type PlanView, type CellOrder,
} from "@/features/home-plan/rules";
import { PAGE_LABEL } from "@/lib/auth/nav";
import { MonthTargetChoice } from "./month-target-choice";

// HD-1 / HD-2 (founder 2026-11-20; Blueprint §5.4 P4): the home plans its own staff. Week, month, plan per staff member
// and the home's own settings. Every status comes from `institution_plan` (one source); every write is a database
// function that checks the role again. Synthetic data only (Phase A). Fixed rules, no AI.
export default async function HomePlanPage({ searchParams }: PageProps<"/heim">) {
  const sp = await searchParams;
  const one = (v: string | string[] | undefined) => (Array.isArray(v) ? v[0] : v);
  const asked: PlanView = one(sp.ansicht) === "auftrag" ? "auftrag" : one(sp.ansicht) === "vorschlag" ? "vorschlag"
    : (PLAN_VIEWS.find((v) => v.key === one(sp.ansicht))?.key ?? "woche");
  const period: DraftPeriod = one(sp.bereich) === "monat" ? "monat" : "woche";
  const today = zurichToday();
  const date = isIsoDate(one(sp.datum)) ? (one(sp.datum) as string) : today;
  const person = one(sp.person);
  const message = messageText(one(sp.meldung), {
    applied: parseCount(one(sp.uebernommen)), refused: parseCount(one(sp.abgelehnt)), affected: parseCount(one(sp.betroffen)),
  });
  const pending = parseWarning(one(sp.warnung));

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
  // Settings are the lead's, a draft is the lead's and the planner's (the database refuses the others anyway); nobody
  // else is shown the forms.
  const view: PlanView = (asked === "einstellungen" && !canSettle(inst.role)) || (asked === "vorschlag" && !canPlan(inst.role)) ? "woche" : asked;
  const { from, to } = rangeFor(view, date);
  const plan = await getPlan(inst.id, from, to);
  // HD-3a-F1 R-7-2: after a partial take-over (or its retry), the persons refused for a missing Pensum, read back from the run record.
  const run = APPLY_RUN_CODES.includes(one(sp.meldung) ?? "") ? parseApplyRun(one(sp.lauf)) : null;
  const refusals = run && canPlan(inst.role) ? await getDraftRunRefusals(inst.id, run) : null;
  const noPensumRefused = refusals && plan ? pensumMissingPersons(refusals, plan.staff) : [];
  const href = (q: Record<string, string | undefined>) => {
    const params = new URLSearchParams();
    const merged = { ansicht: view, datum: date, person, ...(view === "vorschlag" ? { bereich: period } : {}), ...q };
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
            href={href({ ansicht: v.key, bereich: undefined })}
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
      {noPensumRefused.length > 0 && (
        <ul role="alert" className="grid gap-1 rounded-lg border border-amber-400 bg-amber-50 p-2 text-sm text-amber-950" data-testid="heim-apply-no-pensum">
          {noPensumRefused.map((p) => (
            <li key={p.id} data-testid="heim-apply-no-pensum-line">
              {pensumMissingText(p)}{" "}
              {p.name !== "Eine Person" && (
                <Link href={`${href({ ansicht: "personal", bereich: undefined, person: p.id })}#heim-staff-planning`}
                  className="inline-grid min-h-11 place-items-center font-semibold underline">
                  Pensum von {p.name} eintragen
                </Link>
              )}
            </li>
          ))}
        </ul>
      )}

      {plan && pending && canPlan(plan.institution.role) && (
        <RuleWarning plan={plan} pending={pending} back={back}
          personHref={(id, d, anchor) => `${href({ ansicht: "personal", bereich: undefined, person: id, datum: d })}#${anchor}`}
          limitsHref={`${href({ ansicht: "einstellungen", bereich: undefined })}#heim-limits`} />
      )}
      {plan && (view === "woche" || view === "monat") && (
        <HoursUnknownLine plan={plan} personHref={(id, d) => href({ ansicht: "personal", bereich: undefined, person: id, datum: d })} />
      )}

      {!plan ? (
        <p role="alert">Der Plan konnte nicht geladen werden.</p>
      ) : view !== "einstellungen" && (plan.stations.length === 0 || plan.shift_types.length === 0) ? (
        <EmptyHome plan={plan} back={back} weekStartDate={rangeFor("woche", today).from} settingsHref={href({ ansicht: "einstellungen" })} />
      ) : view === "woche" ? (
        <WeekView plan={plan} back={back} prev={href({ datum: addDays(from, -7) })} next={href({ datum: addDays(from, 7) })}
          todayHref={href({ datum: today })} draftHref={href({ ansicht: "vorschlag", bereich: "woche" })} />
      ) : view === "monat" ? (
        <MonthView plan={plan} prev={href({ datum: addDays(from, -1) })} next={href({ datum: addDays(to, 1) })}
          personHref={(id) => href({ ansicht: "personal", person: id })} draftHref={href({ ansicht: "vorschlag", bereich: "monat" })} />
      ) : view === "vorschlag" ? (
        <DraftProposal institutionId={inst.id} period={period} date={date}
          back={href({ ansicht: period, bereich: undefined })}
          limitsHref={canSettle(inst.role) ? `${href({ ansicht: "einstellungen", bereich: undefined })}#heim-limits` : null}
          personHref={(id) => `${href({ ansicht: "personal", bereich: undefined, person: id })}#heim-staff-planning`} />
      ) : view === "auftrag" ? (
        <OrderReview plan={plan} back={back} draft={one(sp.entwurf)} weekHref={href({ ansicht: "woche", entwurf: undefined })}
          values={{
            postcode: one(sp.postcode) || null, grade: one(sp.grade) || null,
            // «Prüfen» returns the shown boxes as `tags` / `req` with the marker `geprueft` (UXR-269); without the marker the
            // tags are the prefill of the last order of this station.
            tags: tagList(one(sp.tags)), req: tagList(one(sp.req)), checked: one(sp.geprueft) === "1",
          }} />
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

// HD-PEN-HAND (PO decision, AUT-247): one line above the week and month: stored shifts of the shown range whose hours
// cannot be checked, with a link to the first affected person. No line when there are none.
function HoursUnknownLine({ plan, personHref }: { plan: Plan; personHref: (id: string, date: string) => string }) {
  const n = hoursUnknownCount(plan);
  if (n.shifts === 0 || !n.first) return null;
  const name = plan.staff.find((p) => p.id === n.first!.staff_id)?.display_name ?? "erste Person";
  return (
    <p role="status" data-testid="heim-hours-unknown-count"
      className="flex flex-wrap items-center gap-2 rounded-lg border border-amber-400 bg-amber-50 p-2 text-sm text-amber-950">
      <span className="font-semibold">{hoursUnknownCountText(n)}</span>
      <Link href={`${personHref(n.first.staff_id, n.first.date)}#heim-staff-planning`}
        className="inline-grid min-h-11 place-items-center underline" data-testid="heim-hours-unknown-first">
        {name} ansehen
      </Link>
    </p>
  );
}

// HD-3a Q3 (FE-123): the hand assignment broke a planning rule. Nothing is saved yet; the person confirms or cancels.
// HD-PEN-HAND: for «Stunden nicht prüfbar» the reason and the next action (links for what this role can enter, the
// role that can enter the rest).
function RuleWarning({ plan, pending, back, personHref, limitsHref }: {
  plan: Plan; pending: PendingWarning; back: string; personHref: (id: string, date: string, anchor: string) => string; limitsHref: string;
}) {
  const person = plan.staff.find((p) => p.id === pending.staff)?.display_name ?? "Diese Person";
  const gap = pending.rules.includes("hours_unknown") ? hoursUnknownNext(plan, pending.staff, pending.date) : null;
  const lead = canSettle(plan.institution.role);
  const t = plan.shift_types.find((x) => x.id === pending.shift);
  const station = plan.stations.find((x) => x.id === pending.station)?.name ?? "";
  return (
    <section role="alert" aria-label="Regelwarnung" data-testid="heim-rule-warning"
      className="grid gap-2 rounded-lg border border-amber-400 bg-amber-50 p-3 text-sm text-amber-950">
      <p className="font-semibold">
        {person} · {t ? `${t.label} ${shiftTimesText(t)}` : "Dienst"}{station ? ` · ${station}` : ""} · {dayLabel(pending.date)}
      </p>
      <ul className="list-disc pl-5" data-testid="heim-rule-warning-rules">
        {pending.rules.map((r) => <li key={r}>{ruleText(r)}</li>)}
      </ul>
      {gap && (
        <div className="grid gap-1" data-testid="heim-rule-hours-unknown">
          <p>{gap.reason} Ohne diese Werte prüft NAVORA die Stunden dieses Diensts nicht.</p>
          <ul className="flex flex-wrap gap-2">
            {gap.actions.filter((a) => lead || !a.lead_only).map((a) => (
              <li key={a.kind}>
                <Link data-testid={`heim-rule-next-${a.kind}`} className="inline-grid min-h-11 place-items-center font-semibold underline"
                  href={a.kind === "weekly_target" ? limitsHref
                    : personHref(pending.staff, pending.date, a.kind === "pensum" ? "heim-staff-planning" : "heim-month-target")}>
                  {a.label}
                </Link>
              </li>
            ))}
          </ul>
          {!lead && gap.actions.some((a) => a.lead_only) && (
            <p className="text-xs" data-testid="heim-rule-next-lead">
              {gap.actions.filter((a) => a.lead_only).map((a) => a.label.replace(" eintragen", "")).join(" und ")} trägt die Heimleitung ein.
            </p>
          )}
        </div>
      )}
      <p>Werte des Heims; Ruhezeit und Arbeitstage in Folge: Arbeitszeitgesetz nicht abschliessend geprüft. Die Warnung bleibt auf dem Dienst sichtbar.</p>
      <div className="flex flex-wrap gap-2">
        <form action={assignStaff}>
          <Hidden values={{ institution: plan.institution.id, station: pending.station, shift: pending.shift, date: pending.date,
            staff: pending.staff, confirm: pending.rules.join(","), back }} />
          <button type="submit" className={btnPrimary} data-testid="heim-rule-confirm">Trotzdem einteilen</button>
        </form>
        <Link href={back} className={`${btn} grid place-items-center`} data-testid="heim-rule-cancel">Abbrechen</Link>
      </div>
    </section>
  );
}
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

function WeekView({ plan, back, prev, next, todayHref, draftHref }: {
  plan: Plan; back: string; prev: string; next: string; todayHref: string; draftHref: string;
}) {
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
        extra={<>
          <Link href={todayHref} className={`${btn} grid place-items-center`}>Heute</Link>
          {planner && <DraftButton href={draftHref} />}
        </>}
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
                        <span className="font-semibold" data-testid="heim-cell-times">{t.label} {shiftTimesText(t)}</span>
                        <span data-testid="heim-cell-status" className={c.status === "gap" ? "font-semibold text-rose-800" : "text-secondary"}>
                          {cellStatusText(c)}
                        </span>
                      </p>
                      <p className="text-xs text-secondary">{requirementText(c)}{c.example ? ` · ${EXAMPLE_NOTE}` : ""}</p>
                      <ul className="grid gap-1">
                        {c.assigned.map((a) => (
                          <li key={a.assignment_id} className="flex flex-wrap items-center justify-between gap-1" data-testid="heim-assigned">
                            <span className={a.absent || a.inactive ? "line-through" : ""}>
                              {a.display_name} <span className="text-xs text-secondary">{gradeLabel(a.grade)}</span>
                              {a.absent && <span className="ml-1 text-xs font-semibold text-rose-800 no-underline">abwesend</span>}
                              {a.inactive && (
                                <span className="ml-1 text-xs font-semibold text-rose-800 no-underline" data-testid="heim-assigned-inactive">
                                  nicht mehr aktiv
                                </span>
                              )}
                              {ruleWarning(a) && (
                                <span className="block text-xs font-semibold text-amber-900 no-underline" data-testid="heim-assigned-warning">
                                  {ruleWarning(a)}
                                </span>
                              )}
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
                      {c.order && (
                        <OrderBlock order={c.order} reviewHref={`${HOME_PLAN_PATH}?ansicht=auftrag&datum=${d}&entwurf=${c.order.gap_order_id}`}
                          planner={planner} withdraw={canWithdrawOrder(plan, c.order)} back={back} />
                      )}
                      {/* HD-3s-F2: a split gap is one order with both blocks (FE-133 (1)); the same button as every gap. */}
                      {canPrepareOrder(plan, c) && (
                        <form action={prepareGapOrder}>
                          <Hidden values={{ institution: plan.institution.id, station: s.id, shift: t.id, date: d, back }} />
                          <button type="submit" className={`${btn} w-full`} data-testid="heim-prepare-order">Externen Auftrag vorbereiten</button>
                        </form>
                      )}
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

function MonthView({ plan, prev, next, personHref, draftHref }: {
  plan: Plan; prev: string; next: string; personHref: (id: string) => string; draftHref: string;
}) {
  const days = daysBetween(plan.from, plan.to);
  const gaps = gapsPerDay(plan);
  const orders = ordersPerDay(plan);
  const people = monthPeople(plan);
  return (
    <section aria-label="Monatsplan" className="grid gap-3">
      <PeriodNav title={monthLabel(plan.from)} prev={prev} next={next}
        extra={canPlan(plan.institution.role) ? <DraftButton href={draftHref} /> : undefined} />
      <p className="text-xs text-secondary">
        Kürzel je Tag: {plan.shift_types.map((t) => `${t.code} = ${t.label} ${shiftTimesText(t)}`).join(" · ")} · A = abwesend
        {" "}· (N) = eingeteilt, zählt aber nicht (abwesend oder nicht mehr aktiv) · eine Nacht steht am Tag ihres Beginns
        {" "}· Extern: E = vorbereitet, A = Angebot versandt, T = Team hat übernommen, G = gedeckt, K = nicht gedeckt, N = nicht mehr gedeckt
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
                    <span className="text-secondary">{gradeLabel(p.grade)}{p.active ? "" : " · nicht mehr aktiv"}</span>
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
            <tr className="border-t border-stone-200">
              <th scope="row" className="sticky left-0 z-10 bg-white p-1 text-left">Extern</th>
              {days.map((d) => (
                <td key={d} className="p-1 text-center" data-testid="heim-month-orders" data-date={d}>
                  {(orders.get(d) ?? []).join(" ")}
                </td>
              ))}
              <td />
            </tr>
          </tbody>
        </table>
      </div>
      <p className="text-xs text-secondary">Stunden = Dienstlänge laut Ihren Dienstarten, ohne Pausenabzug; Abwesenheiten zählen nicht.</p>
      <MonthTargets plan={plan} people={people} personHref={personHref} />
    </section>
  );
}

// HD-3a-F3 (founder FE-135 option A): Monatssoll, geplante Stunden and Reststunden per person for the shown month, all
// read from the database (T-1). Planned = working minutes of the whole month (split shift without its pause), the
// count the rule R-m uses; the column «Std.» above stays the shown range's shift length. The warning stays in the
// person's row (AUT-240: no banner per person); one home line says when every deviation is shown.
function MonthTargets({ plan, people, personHref }: {
  plan: Plan; people: ReadonlyArray<Plan["staff"][number]>; personHref: (id: string) => string;
}) {
  if (!plan.month_targets) return null;
  const rows = people.filter((p) => p.active).map((p) => ({ p, m: monthTargetOf(plan, p.id, plan.from) }));
  const withTarget = rows.filter((r) => r.m?.target_minutes != null).length;
  const threshold = plan.institution.monthly_target_deviation_hours ?? null;
  return (
    <div className="grid gap-2 rounded-lg border border-stone-200 bg-white p-3" data-testid="heim-month-targets">
      <h3 className="font-semibold">Monatssoll {monthLabel(plan.from)}</h3>
      <p className="text-xs text-secondary">
        Monatssoll eingetragen für {withTarget} von {rows.length} aktiven Personen. Mit Monatssoll gilt es für diesen Monat
        {" "}statt des Wochenbudgets; ohne gilt das Wochenbudget (Pensum × Wochensoll). Ruhezeit, Arbeitstage in Folge,
        {" "}Schichtmodell, Abwesenheit und Doppelbelegung gelten immer. {LIMIT_MARK}.
      </p>
      {withTarget > 0 && threshold === null && (
        <p className="text-xs text-amber-950" data-testid="heim-month-targets-no-threshold">
          Abweichungsschwelle nicht gesetzt: jede Abweichung vom Vergleichswert wird angezeigt.
        </p>
      )}
      <ul className="grid gap-1 text-sm">
        {rows.map(({ p, m }) => (
          <li key={p.id} className="grid gap-0.5 border-t border-stone-100 pt-1" data-testid="heim-month-target-row" data-staff={p.display_name}>
            <span>
              <Link href={personHref(p.id)} className="underline">{p.display_name}</Link>{" "}
              <MonthTargetNumbers m={m} />
            </span>
            <MonthTargetWarning m={m} />
          </li>
        ))}
      </ul>
    </div>
  );
}

function MonthTargetNumbers({ m }: { m: MonthTarget | null }) {
  if (!m) return null;
  if (m.target_minutes == null) {
    return (
      <span className="text-secondary" data-testid="heim-month-target-none">
        kein Monatssoll: Wochenbudget gilt · {minutesAsHours(m.planned_minutes)} geplant
      </span>
    );
  }
  return (
    <span data-testid="heim-month-target-numbers">
      Soll {minutesAsHours(m.target_minutes)} · geplant {minutesAsHours(m.planned_minutes)} ·{" "}
      <span className={(m.remaining_minutes ?? 0) < 0 ? "font-semibold text-rose-800" : "font-semibold"} data-testid="heim-month-target-remaining">
        Rest {minutesAsHours(m.remaining_minutes ?? 0)}
      </span>
    </span>
  );
}

/** Founder requirement 2: a visible warning when the target deviates from the comparison value; never a changed value. */
function MonthTargetWarning({ m }: { m: MonthTarget | null }) {
  if (!m || m.target_minutes == null) return null;
  if (m.comparison_minutes == null) {
    return (
      <span className="text-xs text-secondary" data-testid="heim-month-target-no-comparison">
        Kein Vergleich möglich: Pensum oder Wochensoll nicht eingetragen.
      </span>
    );
  }
  if (!m.deviates) return null;
  return (
    <span className="text-xs font-semibold text-amber-900" data-testid="heim-month-target-deviates">
      Weicht ab: Vergleichswert aus Pensum × Wochensoll {minutesAsHours(m.comparison_minutes)} (Unterschied{" "}
      {minutesAsHours(Math.abs(m.target_minutes - m.comparison_minutes))}). Das eingetragene Monatssoll gilt; nichts wurde geändert.
    </span>
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
                {withoutPensumAndTarget(plan, s.id) ? <span className="font-semibold text-amber-900" data-testid="heim-staff-no-pensum"> · ohne Pensum</span> : ""}
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
  const worked = days.filter((d) => !d.absent && d.shifts.some((s) => s.counts)).length;
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
            <label className="grid gap-1 text-sm">Art
              <select name="kind" defaultValue="absent" className={input} data-testid="heim-absence-kind">
                {ABSENCE_KINDS.map((k) => <option key={k} value={k}>{absenceKindLabel(k)}</option>)}
              </select>
            </label>
            <button type="submit" className={btn}>Abwesenheit erfassen</button>
            <p className="w-full text-xs text-secondary">Ohne Grund: NAVORA fragt und speichert keinen Abwesenheitsgrund, nur die Art.</p>
          </form>
          <form action={setStaffActive}>
            <Hidden values={{ staff: staff.id, active: staff.active ? "false" : "true", back }} />
            <button type="submit" className={btn}>{staff.active ? "Nicht mehr aktiv" : "Wieder aktiv"}</button>
          </form>
        </div>
      )}
      <StaffPlanning plan={plan} staff={staff} back={back} planner={planner} />
      <PersonMonthTarget plan={plan} staff={staff} back={back} />
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
              <span key={s.assignment_id} className={s.counts ? "" : "line-through"}>
                {s.label} {s.time} · {s.station}
                {!s.counts && !d.absent && <span className="ml-1 font-semibold text-rose-800 no-underline">zählt nicht</span>}
                {s.warning && <span className="ml-1 font-semibold text-amber-900 no-underline" data-testid="heim-person-warning">{s.warning}</span>}
              </span>
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
      <PlanningLimits plan={plan} back={back} />
      <ThresholdForm plan={plan} back={back} />
      <div className="grid content-start gap-3 rounded-lg border border-stone-300 bg-white p-3 lg:col-span-2">
        <WorkDaysForm plan={plan} back={back} />
      </div>
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
        <ul className="grid gap-2 text-sm" data-testid="heim-shift-types">
          {plan.shift_types.map((t) => (
            <li key={t.id} className="grid gap-1" data-testid="heim-shift-type" data-code={t.code}>
              <span>{t.code} · {t.label} <span data-testid="heim-shift-times">{shiftTimesText(t)}</span> · <span data-testid="heim-shift-class-now">Klasse: {shiftClassLabel(t.shift_class)}</span></span>
              {isSplit(t) ? <SplitHint plan={plan} t={t} /> : (
              <form action={setShiftClass} className="flex flex-wrap items-end gap-2" data-testid="heim-shift-class-form">
                <Hidden values={{ institution: plan.institution.id, shift: t.id, was_class: shownValue(t.shift_class), back }} />
                <label className="grid gap-1 text-sm">Schichtklasse {t.code}
                  <select name="class" defaultValue={t.shift_class ?? NO_CLASS} className={input} data-testid="heim-shift-class">
                    {SELECTABLE_SHIFT_CLASSES.map((c) => <option key={c} value={c}>{SHIFT_CLASS_LABEL[c]}</option>)}
                    <option value={NO_CLASS}>keine Klasse</option>
                  </select>
                </label>
                <button type="submit" className={btn} data-testid="heim-shift-class-save">Klasse speichern</button>
              </form>
              )}
            </li>
          ))}
        </ul>
        <p className="text-xs text-secondary">
          Die Klasse sagt, welche Personen eine Dienstart übernehmen dürfen (Schichtmodell). Ohne Klasse nur Personen mit
          «alle Dienste». Eine Änderung entfernt keine Einteilung; NAVORA zeigt, wie viele nicht mehr passen.
        </p>
        <form action={setShiftType} className="flex flex-wrap items-end gap-2">
          <Hidden values={{ institution: plan.institution.id, back }} />
          <label className="grid gap-1 text-sm">Kürzel<input name="code" required maxLength={12} className={`${input} w-16`} /></label>
          <label className="grid gap-1 text-sm">Name<input name="label" required maxLength={40} className={`${input} w-28`} /></label>
          <label className="grid gap-1 text-sm">von<input type="time" name="starts" required className={input} /></label>
          <label className="grid gap-1 text-sm">bis<input type="time" name="ends" required className={input} /></label>
          <button type="submit" className={btn}>Speichern</button>
        </form>
        <p className="text-xs text-secondary">Gleiches Kürzel überschreibt die Dienstart. Endet ein Dienst vor seinem Beginn, endet er am Folgetag.</p>
        <SplitShiftForm plan={plan} back={back} />
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
                  data-testid="heim-rule-form" data-station={s.name} data-shift={t.code}>
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

const toneClass: Record<string, string> = {
  draft: "border-stone-300 bg-stone-50",
  wait: "border-amber-300 bg-amber-50 text-amber-900",
  ok: "border-emerald-900/20 bg-emerald-50 text-emerald-900",
  alert: "border-rose-400 bg-rose-50 text-rose-800",
};

// HD-2: the external order of a cell in the words of brief HD.md §3; the database decides the state (one source).
function OrderBlock({ order, reviewHref, planner, withdraw, back }: {
  order: CellOrder; reviewHref: string; planner: boolean; withdraw: boolean; back: string;
}) {
  const line = orderLine(order);
  return (
    <div role="status" className={`grid gap-0.5 rounded-md border p-2 text-xs ${toneClass[line.tone]}`}
      data-testid="heim-cell-order" data-code={line.code} data-order-id={order.order_id ?? undefined}>
      <p className="font-semibold" data-testid="heim-cell-order-headline">Externer Auftrag: {line.headline}</p>
      {line.detail && <p>{line.detail}</p>}
      {line.next && <p className="font-semibold" data-testid="heim-cell-order-next">{line.next}</p>}
      {planner && order.state === "prepared" && (
        <Link href={reviewHref} className="underline" data-testid="heim-order-review-link">Prüfen und senden</Link>
      )}
      {withdraw && (
        // HD-2 slice 5: no team is offered it afterwards; a live take is released and its planned visit removed.
        <form action={withdrawGapOrder}>
          <Hidden values={{ gap: order.gap_order_id, back }} />
          <button type="submit" className="min-h-11 text-left font-semibold underline" data-testid="heim-order-withdraw">
            Auftrag zurückziehen
          </button>
        </form>
      )}
    </div>
  );
}

// HD-2: review screen of a draft. Date, shift and (for a missing grade) the grade come from the cell; the home adds its
// postcode and the activities. «Prüfen» runs preview_client_order; «Senden» runs confirm_client_order (one order path).
async function OrderReview({ plan, back, draft, weekHref, values }: {
  plan: Plan; back: string; draft: string | undefined; weekHref: string;
  values: { postcode: string | null; grade: string | null; tags: string[]; req: string[]; checked: boolean };
}) {
  const cell = cellOfDraft(plan, draft);
  if (!cell || !cell.order || cell.order.state !== "prepared") {
    return (
      <section className="grid gap-2 rounded-lg border border-stone-300 bg-white p-4" data-testid="heim-order-review-missing">
        <p>Dieser Entwurf ist nicht mehr offen.</p>
        <Link href={weekHref} className="underline">Zur Woche</Link>
      </section>
    );
  }
  const order = cell.order;
  const station = plan.stations.find((x) => x.id === cell.station_id);
  const shift = plan.shift_types.find((x) => x.id === cell.shift_type_id);
  const postcode = values.postcode ?? plan.institution.order_postcode ?? null;
  const grade = order.grade_fixed ? order.grade : values.grade;
  const choices = await getOrderChoices();
  const preview = postcode && grade && values.tags.length > 0
    ? await previewGapOrder({ gap: order.gap_order_id, postcode, grade, tags: values.tags, req: values.req })
    : null;
  const problems = preview?.result === "ok" ? (preview.preview?.problems ?? []) : (preview?.problems ?? []);
  const key = crypto.randomUUID();
  const canSend = Boolean(preview && problems.length === 0 && postcode && grade);
  // UXR-269: the line next to «Senden» comes from the same values the preview checked and the snapshot carries.
  const summary = canSend
    ? orderSendSummary({
      grade: grade!, day: dayLabel(cell.date), time: shift ? shiftTimesText(shift) : "", postcode: postcode!,
      place: choices.postcodes.find((p) => p.postcode === postcode)?.place_name ?? null, tags: values.tags, activities: choices.activities,
    })
    : null;
  // A new key per checked state remounts the form, so the boxes always start from the values that were checked.
  const formKey = `${postcode ?? ""}|${grade ?? ""}|${[...values.tags].sort().join(",")}|${values.checked ? 1 : 0}`;
  return (
    <section aria-label="Externen Auftrag prüfen" className="grid max-w-2xl gap-3 rounded-lg border border-stone-300 bg-white p-4" data-testid="heim-order-review">
      <h2 className="text-lg font-bold">Externen Auftrag prüfen</h2>
      <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-sm">
        <dt className="text-secondary">Dienst</dt>
        <dd data-testid="heim-order-review-shift">{dayLabel(cell.date)} · {station?.name} · {shift?.label} {shift ? shiftTimesText(shift) : ""}</dd>
        <dt className="text-secondary">Lücke</dt>
        <dd>{cellStatusText(cell)}</dd>
        {order.grade_fixed && (<><dt className="text-secondary">Stufe</dt><dd data-testid="heim-order-review-grade">{gradeLabel(order.grade)} (fehlt in diesem Dienst)</dd></>)}
      </dl>
      {/* UXR-269: one form for «Prüfen» and «Senden», so «Senden» submits the boxes exactly as shown; the server sends
          only when they equal the checked snapshot below, otherwise it asks to check again. Works without a script. */}
      <form key={formKey} className="grid gap-3" action={checkGapOrder}>
        <Hidden values={{ gap: order.gap_order_id, date: cell.date, back }} />
        {order.grade_fixed && grade && <input type="hidden" name="grade" value={grade} />}
        {values.req.map((t) => <input key={t} type="hidden" name="req" value={t} />)}
        <label className="grid gap-1 text-sm">
          <span className="font-semibold">Postleitzahl des Heims</span>
          <select name="postcode" defaultValue={postcode ?? ""} className={input} data-testid="heim-order-postcode">
            <option value="">Bitte wählen</option>
            {choices.postcodes.map((p) => <option key={p.postcode} value={p.postcode}>{p.postcode} {p.place_name}</option>)}
          </select>
        </label>
        {!order.grade_fixed && (
          <label className="grid gap-1 text-sm">
            <span className="font-semibold">Stufe</span>
            <select name="grade" defaultValue={grade ?? ""} className={input} data-testid="heim-order-grade">
              <option value="">Bitte wählen</option>
              {GRADE_CHOICES.map((g) => <option key={g.value} value={g.value}>{g.label}</option>)}
            </select>
          </label>
        )}
        <fieldset className="grid gap-1 text-sm">
          <legend className="font-semibold">Tätigkeiten</legend>
          {values.tags.length > 0 && !values.checked && (
            <p className="text-xs text-secondary" data-testid="heim-order-prefill-hint">Vorbelegt wie beim letzten Auftrag dieser Station; bitte prüfen.</p>
          )}
          <div className="grid gap-1 sm:grid-cols-2">
            {choices.activities.map((a) => (
              <label key={a.code} className="flex min-h-11 items-center gap-2">
                <input type="checkbox" name="tag" value={a.code} defaultChecked={values.tags.includes(a.code)} data-testid="heim-order-tag" />
                <span>{a.code} · {a.label_de}</span>
              </label>
            ))}
          </div>
        </fieldset>
        <button type="submit" className={btn} data-testid="heim-order-check">Prüfen</button>
        {preview && (
          problems.length === 0 ? (
            <p role="status" className="rounded-md border border-emerald-900/20 bg-emerald-50 p-2 text-sm" data-testid="heim-order-sentence">
              {preview.preview?.sentence}
            </p>
          ) : (
            <ul role="alert" className="grid gap-1 rounded-md border border-rose-300 bg-rose-50 p-2 text-sm text-rose-800" data-testid="heim-order-problems">
              {problems.map((p) => <li key={p}>{messageText(p)?.text ?? p}</li>)}
            </ul>
          )
        )}
        {canSend && (
          <div className="grid gap-2">
            <Hidden values={{ key, checked_postcode: postcode!, checked_grade: grade! }} />
            {values.tags.map((t) => <input key={t} type="hidden" name="checked_tag" value={t} />)}
            <p className="break-words text-sm" data-testid="heim-order-send-summary">{summary}</p>
            <button type="submit" formAction={sendGapOrder} className={`${btnPrimary} justify-self-start`} data-testid="heim-order-send">
              Senden: Angebot an alle passenden Teams
            </button>
          </div>
        )}
      </form>
      <div className="flex flex-wrap gap-2">
        <form action={discardGapOrder}>
          <Hidden values={{ gap: order.gap_order_id, back }} />
          <button type="submit" className={btn} data-testid="heim-order-discard">Verwerfen</button>
        </form>
        <Link href={weekHref} className={`${btn} grid place-items-center`}>Zur Woche</Link>
      </div>
    </section>
  );
}

function DraftButton({ href }: { href: string }) {
  return (
    <Link href={href} data-testid="heim-draft-start"
      className="grid min-h-11 place-items-center rounded-lg border border-emerald-800 bg-emerald-800 px-3 text-sm font-semibold text-white">
      Plan vorschlagen
    </Link>
  );
}

// HD-3a slice 4 (brief HD.md §5b; ADR-224 rev. 2): «Plan vorschlagen» for the shown week or month. The solver runs here
// on the server on this home's plan (`institution_plan`, also the weeks around the period it needs for the rules) and
// saves nothing. «Übernehmen» sends exactly the rows shown here (T-1) with one apply id; the database checks each row
// again and refuses what no longer fits. Fixed, checkable rules, no AI.
async function DraftProposal({ institutionId, period, date, back, limitsHref, personHref }: {
  institutionId: string; period: DraftPeriod; date: string; back: string;
  /** FE-128: «Kein Vorschlag» points at the limit fields; null for a planner (only the lead sets them). */
  limitsHref: string | null; personHref: (id: string) => string;
}) {
  const { from, to } = draftPeriodRange(period, date);
  const title = period === "woche" ? `KW ${isoWeek(from)} · ${dayLabel(from)} bis ${dayLabel(to)}` : monthLabel(from);
  const plan = await getDraftPlan(institutionId, from, to);
  const head = (
    <>
      <h2 className="text-lg font-bold">Planvorschlag · {title}</h2>
      <p className="text-xs text-secondary" data-testid="heim-draft-mark">
        {DRAFT_MARK} · {WORKING_TIME_LAW_MARK} · Noch nicht gespeichert: erst «Übernehmen» teilt ein.
      </p>
    </>
  );
  const cancel = <Link href={back} className={`${btn} grid place-items-center`} data-testid="heim-draft-cancel">Zurück zum Plan</Link>;
  if (!plan) {
    return <section aria-label="Planvorschlag" className="grid gap-3" data-testid="heim-draft">{head}<p role="alert">Der Plan konnte nicht geladen werden.</p>{cancel}</section>;
  }
  const input = draftInputFromPlan(plan, from, to);
  const timed = input ? timedDraft(input) : null;
  const result = timed?.result ?? null;
  const ms = timed?.ms ?? 0;
  if (!result || result.result !== "ok") {
    const why = !result
      ? "Ruhezeit oder Arbeitstage in Folge des Heims fehlen, oder eine Angabe passt nicht zu dieser App-Version."
      : "Das Wochensoll des Heims (Stunden pro Woche bei 100 %) ist nicht eingetragen.";
    return (
      <section aria-label="Planvorschlag" className="grid gap-3" data-testid="heim-draft">
        {head}
        <p role="alert" data-testid="heim-draft-none">Kein Vorschlag: {why}</p>
        {limitsHref ? (
          <Link href={limitsHref} className={`${btnPrimary} grid w-fit place-items-center`} data-testid="heim-draft-limits-link">
            Planungsgrenzen eintragen
          </Link>
        ) : (
          <p className="text-sm" data-testid="heim-draft-limits-lead">Diese Werte trägt die Heimleitung ein (Einstellungen · Planungsgrenzen).</p>
        )}
        {cancel}
      </section>
    );
  }
  const rows = sortRows(result.rows, plan);
  const gaps = sortGaps(result.gaps, plan);
  const station = new Map(plan.stations.map((s) => [s.id, s]));
  const shift = new Map(plan.shift_types.map((t) => [t.id, t]));
  const person = new Map(plan.staff.map((s) => [s.id, s]));
  const shiftText = (id: string) => {
    const t = shift.get(id);
    return t ? `${t.label} ${shiftTimesText(t)}` : "";
  };
  const days = daysBetween(from, to).filter((d) => rows.some((r) => r.date === d) || gaps.some((g) => g.date === d));
  const unmet = result.wishes.unmet;
  // FE-128: persons without Pensum are never planned automatically (R-b); the lead and the planner see who and go to
  // exactly that field.
  // HD-3a-F3: a person with a monthly target in a month of the period is planned by that target (R-m).
  const hasTarget = (id: string) => (plan.month_targets ?? []).some((m) => m.staff_id === id && m.target_minutes != null
    && m.month <= to && m.month >= `${from.slice(0, 7)}-01`);
  const noPensum = plan.staff.filter((s) => s.active && s.pensum_pct == null && !hasTarget(s.id));
  return (
    <section aria-label="Planvorschlag" className="grid gap-3" data-testid="heim-draft">
      {head}
      <p className="font-semibold" data-testid="heim-draft-summary">
        {rows.length} {rows.length === 1 ? "Dienst" : "Dienste"} vorgeschlagen · {gaps.length} {gaps.length === 1 ? "Lücke bleibt" : "Lücken bleiben"}
        {" "}· berechnet in {ms} ms
      </p>
      {noPensum.length > 0 && (
        <div className="grid gap-1 rounded-lg border border-amber-400 bg-amber-50 p-2 text-sm text-amber-950" data-testid="heim-draft-no-pensum">
          <p>
            {noPensum.length} {noPensum.length === 1 ? "Person wird" : "Personen werden"} nicht automatisch eingeteilt, weil weder
            Pensum noch Monatssoll eingetragen ist:
          </p>
          <ul className="flex flex-wrap gap-2">
            {noPensum.map((s) => (
              <li key={s.id}>
                <Link href={personHref(s.id)} className="inline-grid min-h-11 place-items-center underline" data-testid="heim-draft-no-pensum-link">
                  {s.display_name}
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}
      {result.wishes.total > 0 && (
        <p className="text-sm" data-testid="heim-draft-wishes">
          Wünsche: {result.wishes.met} von {result.wishes.total} erfüllt.
        </p>
      )}
      <div className="flex flex-wrap gap-2">
        {rows.length > 0 && (
          <form action={applyDraft}>
            <Hidden values={{ institution: plan.institution.id, apply: newApplyId(), rows: rowsFormValue(rows), back }} />
            <button type="submit" data-testid="heim-draft-apply"
              className="min-h-11 rounded-lg border border-emerald-800 bg-emerald-800 px-3 text-sm font-semibold text-white">
              Vorschlag übernehmen ({rows.length} {rows.length === 1 ? "Dienst" : "Dienste"})
            </button>
          </form>
        )}
        {cancel}
      </div>
      {rows.length === 0 && gaps.length === 0 && <p data-testid="heim-draft-empty">Nichts vorzuschlagen: Jeder Dienst mit Vorgabe ist besetzt.</p>}
      {days.map((d) => (
        <details key={d} open={period === "woche"} className="rounded-lg border border-stone-200 bg-white p-2" data-testid="heim-draft-day" data-date={d}>
          <summary className="min-h-11 cursor-pointer py-2 font-semibold">{dayLabel(d)}</summary>
          <ul className="grid gap-1 text-sm">
            {rows.filter((r) => r.date === d).map((r) => {
              const p = person.get(r.staff_id);
              return (
                <li key={`${r.staff_id}-${r.station_id}-${r.shift_type_id}`} data-testid="heim-draft-row"
                  data-station={station.get(r.station_id)?.name} data-shift={shift.get(r.shift_type_id)?.code}>
                  <span className="font-semibold">Neu:</span> {station.get(r.station_id)?.name} · {shiftText(r.shift_type_id)} · {p?.display_name} ({gradeLabel(p?.grade ?? null)})
                </li>
              );
            })}
            {gaps.filter((g) => g.date === d).map((g) => (
              <li key={`gap-${g.station_id}-${g.shift_type_id}`} className="text-rose-800" data-testid="heim-draft-gap"
                data-station={station.get(g.station_id)?.name} data-shift={shift.get(g.shift_type_id)?.code}>
                <span className="font-semibold">Lücke:</span> {station.get(g.station_id)?.name} · {shiftText(g.shift_type_id)} · {gapReasonText(g, gradeLabel)}
              </li>
            ))}
          </ul>
        </details>
      ))}
      {unmet.length > 0 && (
        <details className="rounded-lg border border-stone-200 bg-white p-2" data-testid="heim-draft-unmet">
          <summary className="min-h-11 cursor-pointer py-2 font-semibold">{unmet.length} {unmet.length === 1 ? "Wunsch" : "Wünsche"} nicht erfüllt</summary>
          <ul className="grid gap-1 text-sm">
            {unmet.map((w) => (
              <li key={`${w.staff_id}-${w.date}-${w.kind}-${w.shift_type_id ?? ""}`}>
                {dayLabel(w.date)} · {person.get(w.staff_id)?.display_name} · {w.kind === "off" ? "frei" : shiftText(w.shift_type_id ?? "")}: {unmetWishReasonText(w)}
              </li>
            ))}
          </ul>
        </details>
      )}
    </section>
  );
}

// HD-3a FE-128 (brief HD.md §5b, PO amendment 2026-11-25 10:39): the home's planning limits, lead only (this view is
// the lead's). Every field carries the mark that the value is the home's and not checked against the law. NAVORA fills
// in no value; the weekly target «nicht eingetragen» is an explicit choice (the draft then fails closed).
function PlanningLimits({ plan, back }: { plan: Plan; back: string }) {
  const i = plan.institution;
  const weekly = i.weekly_target_hours ?? null;
  return (
    <form action={setPlanningLimits} id="heim-limits" className="grid content-start gap-3 rounded-lg border border-stone-300 bg-white p-3 lg:col-span-2"
      data-testid="heim-limits-form">
      <h2 className="text-lg font-bold">Planungsgrenzen</h2>
      <p className="text-xs text-secondary" data-testid="heim-limits-mark">{LIMIT_MARK}. Der Planvorschlag braucht alle drei Werte.</p>
      <Hidden values={{
        institution: i.id, back,
        was_rest: shownValue(i.min_rest_hours), was_days: shownValue(i.max_consecutive_days), was_weekly: shownValue(weekly),
      }} />
      <div className="flex flex-wrap items-end gap-3">
        <label className="grid gap-1 text-sm">Ruhezeit (Stunden)
          <input name="rest" inputMode="numeric" defaultValue={i.min_rest_hours ?? ""} required className={`${input} w-24`} data-testid="heim-limits-rest" />
        </label>
        <label className="grid gap-1 text-sm">Arbeitstage in Folge (höchstens)
          <input name="days" inputMode="numeric" defaultValue={i.max_consecutive_days ?? ""} required className={`${input} w-24`} data-testid="heim-limits-days" />
        </label>
        <fieldset className="grid gap-1 text-sm">
          <legend>Wochensoll bei 100 % (Stunden)</legend>
          <div className="flex flex-wrap items-center gap-2">
            <label className="flex min-h-11 items-center gap-1">
              <input type="radio" name="weekly_choice" value="wert" defaultChecked={weekly !== null} data-testid="heim-limits-weekly-value" /> Wert
            </label>
            <input name="weekly" inputMode="decimal" aria-label="Wochensoll in Stunden" defaultValue={weekly === null ? "" : String(weekly).replace(".", ",")}
              className={`${input} w-24`} data-testid="heim-limits-weekly" />
            <label className="flex min-h-11 items-center gap-1">
              <input type="radio" name="weekly_choice" value={NOT_ENTERED} data-testid="heim-limits-weekly-none" /> nicht eingetragen
            </label>
          </div>
        </fieldset>
        <button type="submit" className={btnPrimary} data-testid="heim-limits-save">Grenzen speichern</button>
      </div>
      <p className="text-sm" data-testid="heim-limits-now">
        Jetzt: Ruhezeit {i.min_rest_hours ?? "nicht eingetragen"}{i.min_rest_hours != null ? " h" : ""} · Arbeitstage in Folge {i.max_consecutive_days ?? "nicht eingetragen"} ·
        Wochensoll {weekly === null ? "nicht eingetragen" : `${String(weekly).replace(".", ",")} h`}
      </p>
    </form>
  );
}

// HD-3s (brief HD-3s.md scope 1): a shift type with two blocks on one day. The screen checks V1-V5 with the same codes
// as the database; the database checks again. No minimum or maximum pause (none given).
function SplitShiftForm({ plan, back }: { plan: Plan; back: string }) {
  return (
    <form action={setSplitShiftType} className="grid gap-2 rounded-md border border-stone-200 p-2" data-testid="heim-split-form">
      <h3 className="text-base font-semibold">Geteilter Dienst (zwei Blöcke)</h3>
      <Hidden values={{ institution: plan.institution.id, back }} />
      <div className="flex flex-wrap items-end gap-2">
        <label className="grid gap-1 text-sm">Kürzel<input name="code" required maxLength={12} className={`${input} w-16`} data-testid="heim-split-code" /></label>
        <label className="grid gap-1 text-sm">Name<input name="label" required maxLength={40} className={`${input} w-32`} data-testid="heim-split-label" /></label>
      </div>
      <fieldset className="flex flex-wrap items-end gap-2">
        <legend className="text-sm">Block 1</legend>
        <label className="grid gap-1 text-sm">von<input type="time" name="b1_starts" required className={input} data-testid="heim-split-b1-starts" /></label>
        <label className="grid gap-1 text-sm">bis<input type="time" name="b1_ends" required className={input} data-testid="heim-split-b1-ends" /></label>
      </fieldset>
      <fieldset className="flex flex-wrap items-end gap-2">
        <legend className="text-sm">Block 2</legend>
        <label className="grid gap-1 text-sm">von<input type="time" name="b2_starts" required className={input} data-testid="heim-split-b2-starts" /></label>
        <label className="grid gap-1 text-sm">bis<input type="time" name="b2_ends" required className={input} data-testid="heim-split-b2-ends" /></label>
      </fieldset>
      <button type="submit" className={`${btn} justify-self-start`} data-testid="heim-split-save">Geteilten Dienst speichern</button>
      <p className="text-xs text-secondary">
        Ein Arbeitstag mit zwei Blöcken am selben Tag. Die Pause zählt nicht als Arbeitszeit; die Ruhezeit beginnt nach
        Block 2. Nur für Personen mit «alle Dienste» oder «kein Nachtdienst». {WORKING_TIME_LAW_MARK}.
      </p>
    </form>
  );
}

// HD-3s S5: the daily target (weekly target ÷ working days per week) next to a split shift: a hint, never a block.
function SplitHint({ plan, t }: { plan: Plan; t: Plan["shift_types"][number] }) {
  const minutes = shiftMinutes(plan.from, { ...t, shift_class: "split" });
  const hint = dailyTargetHint(minutes, plan.institution.weekly_target_hours, plan.institution.work_days_per_week ?? 5);
  return (
    <p className="text-xs text-secondary" data-testid="heim-split-hint">
      {hint ? dailyTargetText(minutes, hint) : plan.institution.weekly_target_hours == null
        ? "Kein Wochensoll eingetragen: kein Hinweis zum Soll pro Tag."
        : "Arbeitszeit entspricht dem Soll pro Tag."}
    </p>
  );
}

// HD-3s S5: «Arbeitstage pro Woche» of the home (default 5); only for the daily target hint.
function WorkDaysForm({ plan, back }: { plan: Plan; back: string }) {
  const days = plan.institution.work_days_per_week ?? 5;
  return (
    <form action={setWorkDaysPerWeek} className="flex flex-wrap items-end gap-2" data-testid="heim-workdays-form">
      <Hidden values={{ institution: plan.institution.id, back }} />
      <label className="grid gap-1 text-sm">Arbeitstage pro Woche (für das Soll pro Tag)
        <input name="work_days" inputMode="numeric" defaultValue={String(days)} required className={`${input} w-20`} data-testid="heim-workdays" />
      </label>
      <button type="submit" className={btn} data-testid="heim-workdays-save">Speichern</button>
      <p className="w-full text-xs text-secondary" data-testid="heim-workdays-now">
        Jetzt: {days} Arbeitstage. Soll pro Tag = Wochensoll ÷ Arbeitstage; nur ein Hinweis, keine Sperre.
      </p>
    </form>
  );
}

// HD-3a FE-128: Pensum and shift model of one person; the lead and the planner change them, everyone with access reads
// them. «Pensum nicht eingetragen» is an explicit choice: the person is then not planned automatically (R-b).
function StaffPlanning({ plan, staff, back, planner }: { plan: Plan; staff: Plan["staff"][number]; back: string; planner: boolean }) {
  const pensum = staff.pensum_pct ?? null;
  const model = staff.shift_model ?? "any";
  const now = (
    <p className="text-sm" data-testid="heim-staff-planning-now">
      Pensum {pensum === null ? "nicht eingetragen" : `${pensum} %`} · Schichtmodell {shiftModelLabel(model)}
    </p>
  );
  if (!planner) return <div id="heim-staff-planning">{now}</div>;
  return (
    <form action={setStaffPlanning} id="heim-staff-planning" className="grid gap-2 rounded-lg border border-stone-300 bg-white p-2" data-testid="heim-staff-planning-form">
      <h3 className="font-semibold">Planung dieser Person</h3>
      {now}
      <Hidden values={{ institution: plan.institution.id, staff: staff.id, was_pensum: shownValue(pensum), was_model: shownValue(staff.shift_model), back }} />
      <div className="flex flex-wrap items-end gap-3">
        <fieldset className="grid gap-1 text-sm">
          <legend>Pensum (%)</legend>
          <div className="flex flex-wrap items-center gap-2">
            <label className="flex min-h-11 items-center gap-1">
              <input type="radio" name="pensum_choice" value="wert" defaultChecked={pensum !== null} data-testid="heim-staff-pensum-value" /> Wert
            </label>
            <input name="pensum" inputMode="numeric" aria-label="Pensum in Prozent" defaultValue={pensum ?? ""} className={`${input} w-20`} data-testid="heim-staff-pensum" />
            <label className="flex min-h-11 items-center gap-1">
              <input type="radio" name="pensum_choice" value={NOT_ENTERED} data-testid="heim-staff-pensum-none" /> nicht eingetragen
            </label>
          </div>
        </fieldset>
        <label className="grid gap-1 text-sm">Schichtmodell
          <select name="model" defaultValue={model} className={input} data-testid="heim-staff-model">
            {SHIFT_MODELS.map((m) => <option key={m} value={m}>{SHIFT_MODEL_LABEL[m]}</option>)}
          </select>
        </label>
        <button type="submit" className={btn} data-testid="heim-staff-planning-save">Planung speichern</button>
      </div>
      <p className="text-xs text-secondary">Ohne Pensum teilt der Planvorschlag diese Person nicht ein. Von Hand einteilen bleibt möglich.</p>
    </form>
  );
}

// HD-3a-F3 (founder FE-135 option A, migration 0189): the monthly target of one person for the shown calendar month.
// Everyone with access reads it; only the lead enters, changes or deletes it (brief: «Heimleitung trägt ein»). «kein
// Monatssoll» is an explicit choice (the weekly budget then applies), never a cleared field. Numbers from the database.
function PersonMonthTarget({ plan, staff, back }: { plan: Plan; staff: Plan["staff"][number]; back: string }) {
  if (!plan.month_targets) return null;
  const m = monthTargetOf(plan, staff.id, plan.from);
  const target = m?.target_minutes ?? null;
  const now = (
    <p className="text-sm" data-testid="heim-person-month-target">
      Monatssoll {monthLabel(plan.from)}: <MonthTargetNumbers m={m} />
    </p>
  );
  const lead = plan.institution.role === "lead";
  return (
    <div id="heim-month-target" className="grid gap-2 rounded-lg border border-stone-300 bg-white p-2" data-testid="heim-person-month-target-box">
      <h3 className="font-semibold">Monatssoll</h3>
      {now}
      <MonthTargetWarning m={m} />
      {lead ? (
        <form action={setMonthlyTarget} className="flex flex-wrap items-end gap-3" data-testid="heim-month-target-form">
          <Hidden values={{ staff: staff.id, month: plan.from.slice(0, 8) + "01", was_target: shownValue(target), back }} />
          <fieldset className="grid gap-1 text-sm">
            <legend>Monatssoll (Stunden)</legend>
            <MonthTargetChoice noValue={NO_VALUE} inputClass={input}
              target={target === null ? "" : minutesAsHours(target).replace(" h", "")} />
          </fieldset>
          <button type="submit" className={btn} data-testid="heim-month-target-save">Monatssoll speichern</button>
        </form>
      ) : (
        <p className="text-xs text-secondary">Das Monatssoll trägt die Heimleitung ein.</p>
      )}
      <p className="text-xs text-secondary">
        Wert des Heims für diesen Kalendermonat; nicht aus dem Wochensoll umgerechnet. Der Planvorschlag hält es ein; Ruhezeit,
        {" "}Arbeitstage in Folge, Schichtmodell, Abwesenheit und Doppelbelegung gelten weiter.
      </p>
    </div>
  );
}

// HD-3a-F3: «Abweichungsschwelle (Stunden)», lead only (this view is the lead's). Empty by default: every deviation of a
// monthly target from its comparison value is shown. NAVORA fills in no number.
function ThresholdForm({ plan, back }: { plan: Plan; back: string }) {
  const i = plan.institution;
  if (i.role !== "lead") return null;
  const t = i.monthly_target_deviation_hours ?? null;
  return (
    <form action={setMonthlyTargetThreshold} className="grid content-start gap-3 rounded-lg border border-stone-300 bg-white p-3 lg:col-span-2"
      data-testid="heim-threshold-form">
      <h2 className="text-lg font-bold">Monatssoll: Abweichungsschwelle</h2>
      <p className="text-xs text-secondary">
        Ab welcher Abweichung vom Vergleichswert (Pensum × Wochensoll × Tage des Monats ÷ 7) eine Warnung erscheint. Ohne
        {" "}Schwelle erscheint sie bei jeder Abweichung. Nur eine Anzeige: kein Wert wird geändert.
      </p>
      <Hidden values={{ institution: i.id, was_threshold: shownValue(t), back }} />
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <label className="flex min-h-11 items-center gap-1">
          <input type="radio" name="threshold_choice" value="wert" defaultChecked={t !== null} data-testid="heim-threshold-value" /> Wert
        </label>
        <input name="threshold" inputMode="decimal" aria-label="Abweichungsschwelle in Stunden"
          defaultValue={t === null ? "" : String(t).replace(".", ",")} className={`${input} w-24`} data-testid="heim-threshold-input" />
        <label className="flex min-h-11 items-center gap-1">
          <input type="radio" name="threshold_choice" value={NO_VALUE} defaultChecked={t === null} data-testid="heim-threshold-none" /> keine Schwelle
        </label>
        <button type="submit" className={btn} data-testid="heim-threshold-save">Schwelle speichern</button>
      </div>
      <p className="text-sm" data-testid="heim-threshold-now">Jetzt: {t === null ? "keine Schwelle (jede Abweichung wird angezeigt)" : `${String(t).replace(".", ",")} h`}</p>
    </form>
  );
}
