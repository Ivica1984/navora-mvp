import { notFound } from "next/navigation";
import { demoPagesEnabled } from "@/lib/flags";
import MatchingDemo from "./matching-demo";

// Legacy mock with invented data and a DEPRECATED score (ADR-006). Hidden by default.
export default function MatchingPage() {
  if (!demoPagesEnabled) notFound();

  return <MatchingDemo />;
}
