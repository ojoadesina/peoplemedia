// THE SCOPES LIST. A fixed band a third of the way down the list is the
// selection: rows scroll THROUGH it, and whichever lands there is chosen. It is
// MODAL — the same scroller and band carry the people you hold (SCOPED), the
// people you don't (UNSCOPED), and a roll of countries (LOCATION); the server
// swaps the rows by changing the element's id, which re-runs this hook fresh.
//
// Selection resolves on SETTLE, not continuously — a highlight strobing past
// every row during a flick reads as noise, not as choosing. That single choice
// is what gives the line its rule too: the line and the marker ARE the settled
// choice made visible, so they leave the moment the list moves and return only
// once it has come to rest on a row.
//
// On settling, the nearest row PULLS ITSELF to the band's centre rather than
// sitting wherever the scroll happened to stop. A row only does that from
// within one row's reach; beyond that the band stands genuinely empty, which is
// what lets the list rest unselected at the top instead of magnetising the
// first row in.
type HookCtx = {
  el: HTMLElement;
  pushEvent: (event: string, payload: object) => void;
  cleanup?: () => void;
  resettle?: () => void;
};

export const Scopes = {
  mounted(this: HookCtx) {
    const scroll = this.el;
    const push = this.pushEvent.bind(this);
    // THE TRANSIENT CLASSES LIVE ON THE SCROLLER, not on #scopes, and that is
    // not a preference. #scopes is the LiveView root: every patch rewrites its
    // class attribute back to whatever the server rendered, so a hook-set
    // `has-selection` survived only until the next update — which is why the
    // letter box vanished and the placeholder came back the moment an item was
    // picked. The scroller keeps its class through a patch because the markup
    // asks LiveView to leave that one attribute alone; see the note on
    // JS.ignore_attributes there. The CSS reaches the bar from here with a
    // sibling combinator.
    // ROWS ARE LOOKED UP FRESH, never captured. The list is patched now — no
    // phx-update="ignore" — so a scope, a letter or a switch of population
    // replaces these nodes underneath us, and a list captured at mount would be
    // a list of elements no longer in the page.
    const rows = () => Array.from(scroll.querySelectorAll<HTMLElement>(".scopes-item"));
    const root = document.getElementById("scopes");
    if (!root || !rows().length) return;

    // THE SHARED MEDIA ELEMENT IS GONE WITH THE BOX. One <video> was borrowed by
    // every row in turn, because nineteen of them would each hold a buffer for a
    // picture nobody was looking at — and the price of sharing was tearing it
    // down on the way out as deliberately as it was set up on the way in.
    //
    // EVERY FRAME OWNS ITS OWN NOW, on the item itself, and that is affordable
    // for the same reason it was not before: a frame is 3.5rem of a row rather
    // than a 7.5rem box, and only the handful of people who have captured
    // anything carry one at all.
    // THE BOXES THAT EXPANDED ARE GONE, and so is everything that opened them.
    // They were a cluster on the right rail answering the band — a mood, a
    // capture, the last letter somebody sent you — and each could be taken to
    // 18rem to be read properly. What they held now lives on the item itself:
    // the capture fills the frame, the words fill the block under it, and there
    // is nothing left beside the band to open.

    let settleTimer: number | undefined;
    // A snap scrolls, which settles, which may snap again. Bounded, so a snap
    // the scroller cannot actually perform (already at either end) gives up
    // instead of retrying forever.
    let snaps = 0;

    const rowHeight = () => rows()[0]?.getBoundingClientRect().height || 1;

    // WHERE THE BAND SITS IS THE STYLESHEET'S ANSWER, and this reads it rather
    // than restating it. The selection box is already ON that line — the CSS put
    // it there — so measuring the box IS the answer, and moving the band becomes
    // a one-line change in app.css with nothing here to fall out of step with
    // it. The fraction below is only a fallback for a surface that somehow has
    // no bar to measure.
    const band = document.getElementById("bar")?.querySelector<HTMLElement>(".focus-box") ?? null;
    const bandCentre = () => {
      if (band) {
        const r = band.getBoundingClientRect();
        return r.top + r.height / 2;
      }
      const r = scroll.getBoundingClientRect();
      return r.top + r.height * 0.34;
    };

    // WHAT THE BAND CAPTURES IS THE HEAD, NOT THE MIDDLE OF THE ROW. A row was a
    // line of text and its middle was the only point it had; it is a round frame
    // now — a HEAD, a join and a PLATE — and centring the row put the brackets
    // across the gap between the two blocks, holding half of one and half of the
    // other.
    //
    // A CSS OFFSET CANNOT FIX THIS, and trying one is how the fault survived a
    // pass: the lead is measured FROM the band, so moving the band moves every
    // row with it and the two stay exactly as misaligned as they were. What has
    // to change is which part of a row is being aimed at.
    //
    // IT ASKS THE ROW WHERE ITS HEAD IS rather than being told the height. The
    // head is a real element with a real box, so a design that gives it a
    // different height tomorrow needs nothing here; a number copied out of the
    // stylesheet would be a second opinion about the same measurement.
    const aim = (el: HTMLElement) => {
      const r = el.getBoundingClientRect();
      const head = el.querySelector<HTMLElement>(".frame");
      if (!head) return r.top + r.height / 2;
      const h = head.getBoundingClientRect();
      return h.top + h.height / 2;
    };

    // The nearest row and how far it is from the band, signed: positive means
    // the row sits below the band, so scrolling down by that much lifts it in.
    const nearest = (): { el: HTMLElement; delta: number } | null => {
      const centre = bandCentre();
      let best: { el: HTMLElement; delta: number } | null = null;
      for (const el of rows()) {
        const delta = aim(el) - centre;
        if (!best || Math.abs(delta) < Math.abs(best.delta)) best = { el, delta };
      }
      return best;
    };

    const clear = () => rows().forEach((i) => i.classList.remove("is-focused"));

    // LEAD AND TRAIL ARE MEASURED, not written into the markup, and that is what
    // frees the list's HEIGHT. They used to be viewport fractions that only
    // worked while the scroller was exactly 50vh; the moment it grew to fill the
    // page they were wrong in both directions — too little lead to open
    // unselected, too much trail to stop scrolling into nothing.
    //
    // Measured, they follow whatever height the layout hands over: a full row
    // DEEPER than the band up top, so the first row rests below it and the list
    // opens with the band standing empty; and exactly enough underneath for the
    // last row to reach the band and no further.
    const pad = () => {
      const ul = scroll.querySelector<HTMLElement>("ul");
      if (!ul) return;
      const rh = rowHeight();
      const offset = bandCentre() - scroll.getBoundingClientRect().top;
      // A FULL ROW deeper than the band, not half of one. Half leaves the first
      // row's centre exactly one row-height from the band, which is precisely
      // the distance `settle` counts as "in reach" — so the list opened with the
      // first row already magnetised in and the band never stood empty. The
      // unselected state, and the "--" that says so, are load-bearing.
      ul.style.paddingTop = `${Math.max(0, offset + rh)}px`;
      ul.style.paddingBottom = `${Math.max(0, scroll.clientHeight - offset - rh / 2)}px`;
    };

    // WHO IS SELECTED NOW BELONGS TO THE SERVER. The hook is still the only
    // thing that can DECIDE it — it owns the scroll, and the answer is a
    // question about pixels — but the panel is real content about a real
    // person, so the process holding the data has to be told. Sent only on
    // change: a settle that lands on the row already chosen is not news.
    let reported: number | null = null;
    const report = (index: number | null) => {
      if (index === reported) return;
      reported = index;
      if (index === null) push("deselect", {});
      else push("select", { index });
    };

    const settle = () => {
      pad();
      scroll.classList.remove("is-scrolling");
      clear();
      const near = nearest();

      // Out of reach — the band is genuinely empty and says so.
      if (!near || Math.abs(near.delta) > rowHeight()) {
        scroll.classList.remove("has-selection");
        report(null);
        snaps = 0;
        return;
      }

      // In reach but off-centre — draw it in, and settle again when it lands.
      // No media yet: the row is still travelling, and a clip that started here
      // would be cut off by the next settle a few hundred milliseconds later.
      //
      // A SCROLLER AT ITS END CANNOT MOVE, and then no scroll event arrives to
      // settle again with — so this retry, which is driven entirely by that
      // event, stops and nothing is ever selected. It does not bite here today
      // only because the lead padding leaves the band out of reach at rest; the
      // presence stream has the same code and different padding, and there it
      // hung the box empty forever. Watch for the scroll that did not happen.
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

    // Each row is its own horizontal snap scroller, so closing one is putting it
    // back to its first page. Smooth, because it is a reversal of a gesture the
    // hand just made and should read as the row sliding back rather than
    // blinking shut.
    const closeSwipes = () => {
      for (const row of scroll.querySelectorAll<HTMLElement>(".row-swipe")) {
        if (row.scrollLeft > 0) row.scrollTo({ left: 0, behavior: "smooth" });
      }
    };

    const take = (el: HTMLElement) => {
      clear();
      el.classList.add("is-focused");
      scroll.classList.add("has-selection");
      report(rows().indexOf(el));
    };

    scroll.addEventListener(
      "scroll",
      () => {
        // AND SO DOES THE ROUND FORM. Moving the list is looking away from
        // whatever was standing over it, the same as pressing outside — and the
        // form covers the rows you have just started reading.
        if (document.getElementById("round-form")) push("round_cancel", {});

        // A SWIPED ROW CLOSES WHEN THE LIST MOVES. The uncovered action belongs
        // to one row at rest; once the list is travelling it is an offer made
        // about a row that is no longer where you left it, and it would still
        // be sitting open behind whatever settles next. Scrolling away from
        // something IS declining it.
        closeSwipes();

        // Moving: no selection, no line, and no placeholder either — a row is
        // passing through the band and they would collide.
        scroll.classList.add("is-scrolling");
        scroll.classList.remove("has-selection");
        clear();
        // The letter box leaves with the selection. Sound continuing over a moving
        // list would be a voice with nobody attached to it.
        window.clearTimeout(settleTimer);
        settleTimer = window.setTimeout(settle, 140);
      },
      { passive: true },
    );

    // ── A FORM CLOSES WHEN YOU LOOK AWAY ────────────────────────────────────
    // ANYTHING OUTSIDE IT IS A CHANGE OF MIND. Pressing a name, a tag, a box
    // that is not one of its own — all of them are somebody having gone back to
    // the list, and a form left standing over it is a form the next press has to
    // get rid of first.
    //
    // THE FOOT IS INSIDE IT. While a round is being made those three buttons ARE
    // the form's controls, so a press there is a press on the form.
    //
    // CAPTURE, so the decision is made before the press reaches whatever it
    // landed on — the same phase, and for the same reason, as the confirm hook.
    const INSIDE = "#round-form, .round-picker, .app-foot";
    const onOutside = (e: Event) => {
      if (!document.getElementById("round-form")) return;
      if ((e.target as HTMLElement).closest?.(INSIDE)) return;
      push("round_cancel", {});
    };
    document.addEventListener("click", onOutside, true);

    // Tapping a row is the same act as scrolling it in — it travels to the band
    // and the band decides, rather than being selected behind the band's back.
    // DELEGATED, because the rows are replaced by patches and a listener bound
    // per row at mount would be bound to elements that no longer exist.
    const onRowClick = (e: Event) => {
      const el = (e.target as HTMLElement).closest?.(".scopes-item") as HTMLElement | null;
      // A press on the uncovered action is that action's, not the row's.
      if (!el || (e.target as HTMLElement).closest?.(".row-scope")) return;
      const r = el.getBoundingClientRect();
      scroll.scrollBy({ top: r.top + r.height / 2 - bandCentre(), behavior: "smooth" });
    };
    scroll.addEventListener("click", onRowClick);

    // THE FIRST REAL GESTURE BUYS THE SOUND BACK. A clip that fell back to
    // muted has no way of knowing when the browser changed its mind, so the
    // next press anywhere is taken as the answer. Cheap enough to leave on:
    // it does nothing at all unless something is actually playing hushed.
    const unhush = () => {
      const m = current();
      if (m && m.muted) m.muted = false;
    };
    document.addEventListener("pointerdown", unhush);

    // THE PANEL USED TO HAVE TO BE WATCHED. Opening it hid the box on the rail
    // and closing it put back whatever the selection still said was chosen — and
    // a hook is told about patches to its OWN element, not to the root three
    // levels above it, so the only way to hear about the class was to observe
    // the attribute. The box is gone and there is nothing left to tear down.

    window.addEventListener("resize", settle);
    // A frame's grace so the flex layout has resolved a real height to measure.
    requestAnimationFrame(() => requestAnimationFrame(settle));

    // ── WHAT A PATCH IS ALLOWED TO DO ───────────────────────────────────────
    // RESTORE IS NOT SETTLE, and running the second where the first belongs is
    // what made the list jump under a moving finger.
    //
    // `settle` DECIDES: it can smooth-scroll the nearest row into the band and
    // it can tell the server the selection changed. Both are right when a
    // gesture has ended and wrong when a patch arrives — a patch is the
    // server answering something the hook already said, so settling again on
    // the strength of it starts the same conversation over: scrollBy fires a
    // scroll event, the scroll event settles, the settle reports, the report
    // patches. `restore` only puts back what the patch took away.
    const restore = () => {
      pad();
      const focused = rows()[reported ?? -1];
      if (!focused) return;
      focused.classList.add("is-focused");
      scroll.classList.add("has-selection");
      // AND THE LETTER WITH IT. The rows are replaced by the patch, so the box
      // is now holding a letter read off an element that is no longer in the
      // page — and if that row's letter changed (somebody wrote while you were
      // looking at them) the box would be showing the old one.
    };

    let pending = 0;
    this.resettle = () => {
      // NOT DURING A GESTURE. The finger is the authority while it is down;
      // re-measuring underneath it is how the list ended up somewhere the
      // person scrolling did not put it.
      if (scroll.classList.contains("is-scrolling")) return;
      cancelAnimationFrame(pending);
      pending = requestAnimationFrame(restore);
    };

    this.cleanup = () => {
      cluster?.removeEventListener("click", onBoxPress);
      document.removeEventListener("click", onOutside, true);
      cancelAnimationFrame(pending);
      watchPanel.disconnect();
      scroll.removeEventListener("click", onRowClick);
      document.removeEventListener("pointerdown", unhush);
      window.removeEventListener("resize", settle);
    };
  },

  updated(this: HookCtx) {
    this.resettle?.();
  },

  // Swapping the list re-mounts this hook, so the old one's observer and its
  // document-level listeners have to go with it or they accumulate one set per
  // switch, each holding a dead scroller.

  destroyed(this: HookCtx) {
    this.cleanup?.();
  },
};
