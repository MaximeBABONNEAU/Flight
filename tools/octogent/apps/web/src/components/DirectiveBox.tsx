import { useEffect, useState } from "react";

import { buildStudioDirectiveUrl } from "../runtime/runtimeEndpoints";

// DirectiveBox — User directive injection panel for the autonomous studio
// director. The user types natural-language guidance ("focus on Phase 0",
// "stop spawning audit workers", "next: implement scaled_dc unit tests");
// on submit, POSTs to /api/studio/directive which persists to disk; the
// director reads it as Tier 0 priority on every wake cycle.

const DIRECTIVE_POLL_MS = 30_000;
const DIRECTIVE_MAX_CHARS = 8_000;

interface DirectiveSnapshot {
  text: string;
  updatedAt: number;
}

const formatRelative = (sec: number): string => {
  if (sec <= 0) return "never";
  const now = Math.floor(Date.now() / 1000);
  const ago = Math.max(0, now - sec);
  if (ago < 5) return "just now";
  if (ago < 60) return `${ago}s ago`;
  const mins = Math.floor(ago / 60);
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.floor(mins / 60);
  return `${hours}h ago`;
};

export const DirectiveBox = () => {
  const [serverDirective, setServerDirective] = useState<DirectiveSnapshot | null>(null);
  const [draft, setDraft] = useState<string>("");
  const [submitting, setSubmitting] = useState<boolean>(false);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [lastSavedAt, setLastSavedAt] = useState<number>(0);

  // Initial load + polling. We do NOT overwrite the user's draft on poll —
  // only update the "saved on server" snapshot (so the user can see when
  // the directive was last persisted).
  useEffect(() => {
    let disposed = false;
    let inflight = false;

    const refresh = async () => {
      if (disposed || inflight) return;
      inflight = true;
      try {
        const response = await fetch(buildStudioDirectiveUrl(), {
          method: "GET",
          headers: { Accept: "application/json" },
          cache: "no-store",
        });
        if (!response.ok) return;
        const json: unknown = await response.json();
        if (typeof json !== "object" || json === null || "error" in json) return;
        const snap = json as { text?: unknown; updatedAt?: unknown };
        const text = typeof snap.text === "string" ? snap.text : "";
        const updatedAt = typeof snap.updatedAt === "number" ? snap.updatedAt : 0;
        if (disposed) return;
        setServerDirective({ text, updatedAt });
        // Only seed the draft on first successful load (when draft is empty
        // and the user hasn't typed anything yet).
        setDraft((current) => (current.length === 0 ? text : current));
      } finally {
        inflight = false;
      }
    };

    void refresh();
    const timer = window.setInterval(() => {
      void refresh();
    }, DIRECTIVE_POLL_MS);

    return () => {
      disposed = true;
      window.clearInterval(timer);
    };
  }, []);

  const handleSubmit = async () => {
    if (submitting) return;
    setSubmitting(true);
    setSubmitError(null);
    try {
      const response = await fetch(buildStudioDirectiveUrl(), {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify({ text: draft }),
      });
      if (!response.ok) {
        const txt = await response.text();
        setSubmitError(`HTTP ${response.status}: ${txt.slice(0, 100)}`);
        return;
      }
      const json: unknown = await response.json();
      if (typeof json === "object" && json !== null && !("error" in json)) {
        const snap = json as { text?: unknown; updatedAt?: unknown };
        const text = typeof snap.text === "string" ? snap.text : "";
        const updatedAt = typeof snap.updatedAt === "number" ? snap.updatedAt : 0;
        setServerDirective({ text, updatedAt });
        setLastSavedAt(updatedAt);
      }
    } catch (e) {
      setSubmitError(e instanceof Error ? e.message : "Network error");
    } finally {
      setSubmitting(false);
    }
  };

  const handleClear = async () => {
    setDraft("");
    setSubmitting(true);
    setSubmitError(null);
    try {
      await fetch(buildStudioDirectiveUrl(), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ text: "" }),
      });
      setServerDirective({ text: "", updatedAt: Math.floor(Date.now() / 1000) });
    } finally {
      setSubmitting(false);
    }
  };

  const draftChars = draft.length;
  const isDirty = serverDirective !== null && draft !== serverDirective.text;
  const savedAgoText = serverDirective
    ? serverDirective.updatedAt > 0
      ? `saved ${formatRelative(serverDirective.updatedAt)}`
      : "no directive yet"
    : "loading…";

  return (
    <section
      className="directive-box"
      aria-label="Studio director user directive"
      style={{
        margin: "8px 16px 0",
        padding: "12px 14px",
        borderRadius: "8px",
        background: "rgba(20, 14, 6, 0.55)",
        border: "1px solid rgba(214, 162, 26, 0.30)",
        fontFamily: "Georgia, 'Cormorant Garamond', serif",
        color: "rgba(255, 245, 220, 0.92)",
      }}
    >
      <header
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "baseline",
          marginBottom: "8px",
        }}
      >
        <h3
          style={{
            margin: 0,
            fontSize: "12px",
            fontWeight: 600,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            color: "rgba(214, 162, 26, 0.92)",
          }}
        >
          Director directive
        </h3>
        <span
          style={{
            fontSize: "11px",
            opacity: 0.55,
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {savedAgoText}
        </span>
      </header>

      <textarea
        value={draft}
        onChange={(e) => {
          setDraft(e.target.value.slice(0, DIRECTIVE_MAX_CHARS));
          setSubmitError(null);
        }}
        placeholder='Tell the director what to focus on. Examples: "Skip P0-J for now", "Implement scaled_dc unit tests next", "Stop audit-only tasks". Empty = no override.'
        rows={4}
        style={{
          width: "100%",
          background: "rgba(0,0,0,0.30)",
          border: "1px solid rgba(214, 162, 26, 0.18)",
          borderRadius: "6px",
          padding: "8px 10px",
          color: "rgba(255, 245, 220, 0.92)",
          fontFamily: "Consolas, Menlo, monospace",
          fontSize: "12px",
          lineHeight: 1.45,
          resize: "vertical",
          minHeight: "70px",
          boxSizing: "border-box",
        }}
      />

      <footer
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginTop: "8px",
          gap: "8px",
        }}
      >
        <span
          style={{
            fontSize: "10px",
            opacity: 0.5,
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {draftChars}/{DIRECTIVE_MAX_CHARS} chars
          {isDirty ? " · unsaved" : ""}
          {lastSavedAt > 0 && !isDirty ? " · saved ✓" : ""}
        </span>
        <span style={{ display: "flex", gap: "8px" }}>
          <button
            type="button"
            onClick={handleClear}
            disabled={submitting || (serverDirective?.text ?? "").length === 0}
            style={{
              background: "rgba(0,0,0,0.35)",
              border: "1px solid rgba(255,255,255,0.20)",
              color: "rgba(255,245,220,0.75)",
              padding: "6px 12px",
              borderRadius: "5px",
              fontSize: "11px",
              fontFamily: "Georgia, serif",
              cursor: "pointer",
              opacity: submitting ? 0.5 : 1,
              letterSpacing: "0.04em",
            }}
          >
            Clear
          </button>
          <button
            type="button"
            onClick={handleSubmit}
            disabled={submitting || !isDirty}
            style={{
              background: isDirty ? "rgba(214, 162, 26, 0.85)" : "rgba(0,0,0,0.35)",
              border: "1px solid rgba(214, 162, 26, 0.50)",
              color: isDirty ? "#1a1208" : "rgba(255,245,220,0.55)",
              padding: "6px 14px",
              borderRadius: "5px",
              fontSize: "11px",
              fontWeight: 600,
              fontFamily: "Georgia, serif",
              cursor: isDirty ? "pointer" : "default",
              opacity: submitting ? 0.6 : 1,
              letterSpacing: "0.06em",
              textTransform: "uppercase",
            }}
          >
            {submitting ? "Saving…" : "Send to Director"}
          </button>
        </span>
      </footer>

      {submitError ? (
        <div
          style={{
            marginTop: "6px",
            fontSize: "11px",
            color: "#faa32c",
            fontStyle: "italic",
          }}
        >
          {submitError}
        </div>
      ) : null}
    </section>
  );
};
