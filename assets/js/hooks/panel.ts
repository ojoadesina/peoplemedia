// THE PANEL. The relationship list's own mechanism, one level in: a band a
// third of the way down, rows scrolling THROUGH it, and whichever settles there
// is chosen.
//
// WHAT IS IN THE LIST IS ROUNDS AND THE WORDS SAID IN THEM. A round is a heading
// and the words under it are the rows, so only the words are `.panel-item` —
// the band is measured off a row's height and snaps rows to itself, and a
// heading of a different height taking part would drag both measurements.
//
// IT USED TO BE A PLAYER. Half this file drove a video, an audio element and a
// progress bar, and all three were fed by a LETTER'S media: the chosen row
// played the correspondence. Words are made, not captured — there is no file on
// one to play — and what a round carries instead is a CAPTURE, drawn on the
// item's own frame out in the list. So the box keeps the one job it can honestly
// do, which is to say where you are, and the machinery that played the other
// thing is gone rather than left running against nothing.
type HookCtx = { el: HTMLElement; cleanup?: () => void; resettle?: () => void };

export const Panel = {
  mounted(this: HookCtx) {
    const scroll = this.el;
    // LOOKED UP FRESH, never captured. The rows are patched — going round adds
    // one, opening a page re-reads them — so a list captured at mount holds
    // detached nodes after the first patch. That is not a slow leak: a detached
    // row measures zero, so rowHeight() went to 0, the lead and trail went to 0,
    // and the panel list slammed to the top and could never select anything
    // again.
    const items = () => Array.from(scroll.querySelectorAll<HTMLElement>(".panel-item"));
    const stage = scroll.parentElement?.querySelector<HTMLElement>(".stage") ?? null;
    if (!items().length || !stage) return;

    let settleTimer: number | undefined;
    // A snap scrolls, which settles, which may snap again. Bounded, so a snap
    // the scroller cannot perform (already at an end) gives up rather than loop.
    let snaps = 0;

    // WHICH ROW IS CHOSEN, kept as an INDEX rather than as the element. A patch
    // replaces the rows, so a remembered element is a node no longer in the
    // page; the position in the list survives.
    let focused: number | null = null;

    const rowHeight = () => items()[0]?.getBoundingClientRect().height || 1;

    // THE BAND SITS A FIXED ROW-AND-A-HALF FROM THE TOP, not a third of the way
    // down. The chosen row reads NEAR THE TOP with a single row peeking above
    // it, rather than adrift near the middle of the panel — a fixed offset
    // rather than a fraction, so it does not drift lower as the panel grows
    // taller. It is measured off the row's real height, which is also why the
    // matching band in the markup is pinned to the same offset.
    const bandFromTop = () => rowHeight() * 1.5;
    const bandCentre = () => scroll.getBoundingClientRect().top + bandFromTop();

    // Lead and trail are MEASURED, not written in the markup. A full row deeper
    // than the band, so the first row rests a row and a half below it and the
    // list opens unselected.
    const pad = () => {
      const ul = scroll.querySelector<HTMLElement>("ul");
      if (!ul) return;
      const rh = rowHeight();
      ul.style.paddingTop = `${Math.max(0, bandFromTop() + rh)}px`;
      ul.style.paddingBottom = `${Math.max(0, scroll.clientHeight - bandFromTop() - rh / 2)}px`;
    };

    const nearest = (): { el: HTMLElement; delta: number } | null => {
      const centre = bandCentre();
      let best: { el: HTMLElement; delta: number } | null = null;
      for (const el of items()) {
        const r = el.getBoundingClientRect();
        const delta = r.top + r.height / 2 - centre;
        if (!best || Math.abs(delta) < Math.abs(best.delta)) best = { el, delta };
      }
      return best;
    };

    // THE BRACES ARE LOAD-BEARING. This was written as a one-expression arrow —
    // `const clear = () => focused = null;` — with the loop that strips the marks
    // on the NEXT line, outside the body. So the loop ran once, at mount, and
    // every call after that only nulled the index: the mark never came off the
    // row it was on, and scrolling away left the old row lit. A concise arrow
    // body swallows exactly one expression and says nothing about the rest.
    const clear = () => {
      focused = null;
      items().forEach((i) => i.classList.remove("is-focused"));
    };

    const settle = () => {
      pad();
      scroll.classList.remove("is-scrolling");
      stage.classList.remove("is-scrolling");
      clear();
      const near = nearest();

      if (!near || Math.abs(near.delta) > rowHeight()) {
        scroll.classList.remove("has-selection");
        snaps = 0;
        return;
      }

      if (Math.abs(near.delta) > 1 && snaps < 3) {
        const before = scroll.scrollTop;
        snaps++;
        scroll.scrollBy({ top: near.delta, behavior: "smooth" });
        window.setTimeout(() => {
          if (scroll.scrollTop === before) {
            snaps = 0;
            take(near.el);
          }
        }, 200);
        return;
      }

      snaps = 0;
      take(near.el);
    };

    const take = (el: HTMLElement) => {
      clear();
      focused = items().indexOf(el);
      el.classList.add("is-focused");
      scroll.classList.add("has-selection");
    };

    scroll.addEventListener(
      "scroll",
      () => {
        // Moving: no selection. A row is passing through the band and the two
        // would collide.
        scroll.classList.add("is-scrolling");
        stage.classList.add("is-scrolling");
        scroll.classList.remove("has-selection");
        clear();
        window.clearTimeout(settleTimer);
        settleTimer = window.setTimeout(settle, 140);
      },
      { passive: true },
    );

    // Clicking a row scrolls it into the band — the same act as scrolling it
    // there by hand. Delegated: a patch replaces these rows, and a listener
    // bound per row at mount would be bound to rows that are no longer in the
    // page.
    scroll.addEventListener("click", (e) => {
      const el = (e.target as HTMLElement).closest?.(".panel-item") as HTMLElement | null;
      if (!el || el.classList.contains("is-focused")) return;
      const r = el.getBoundingClientRect();
      scroll.scrollBy({ top: r.top + r.height / 2 - bandCentre(), behavior: "smooth" });
    });

    window.addEventListener("resize", settle);

    // ── WHAT A PATCH IS ALLOWED TO DO ───────────────────────────────────────
    // Only put back what the patch took: the measured lead and trail, and the
    // mark on the row already chosen. NOT `settle`, which is allowed to
    // smooth-scroll — an answer to a gesture, and running it on the strength of
    // a patch starts a loop with the server. See the long note in scopes.ts,
    // where this cost the whole list.
    const restore = () => {
      pad();
      const el = items()[focused ?? -1];
      if (el) el.classList.add("is-focused");
    };

    let pending = 0;
    this.resettle = () => {
      if (scroll.classList.contains("is-scrolling")) return;
      cancelAnimationFrame(pending);
      pending = requestAnimationFrame(restore);
    };

    this.cleanup = () => {
      cancelAnimationFrame(pending);
      // Never removed before, so every relationship you opened left one more
      // listener behind holding a scroller that was gone.
      window.removeEventListener("resize", settle);
    };

    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        pad();
        settle();
      }),
    );
  },

  updated(this: HookCtx) {
    this.resettle?.();
  },

  destroyed(this: HookCtx) {
    this.cleanup?.();
  },
};
