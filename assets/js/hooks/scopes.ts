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

    // THE FRAME is ONE element that every row borrows in turn, rather than one
    // letter box per row: nineteen <video> tags would each hold a buffer for a
    // picture nobody is looking at. The cost of sharing is that the media must
    // be torn down on the way out as deliberately as it is set up on the way in.
    const box = document.getElementById("letterbox");
    const video = box?.querySelector<HTMLVideoElement>(".letterbox-video") ?? null;
    const audio = box?.querySelector<HTMLAudioElement>(".letterbox-audio") ?? null;
    const words = box?.querySelector<HTMLElement>(".letterbox-words") ?? null;
    const restart = box?.querySelector<HTMLButtonElement>(".letterbox-restart") ?? null;

    // THE FRAME'S STATE IS CLASSES, NOT DATA ATTRIBUTES, and that is forced by
    // LiveView rather than chosen: on a patched element it strips a client-set
    // src, and on an ignored one it still merges data-* from the server's copy
    // and deletes any the client added. Classes it leaves alone in both cases,
    // so the letter box keeps its own mind across a re-render. `mode` is tracked in a
    // plain variable because reading it back out of a class list would be
    // guessing at what we ourselves wrote.
    // A TEXT LETTER IS A MODE LIKE THE OTHER TWO. It was missing, so a letter
    // that was only words fell through every branch and landed in the box as a
    // blank wash — indistinguishable from having no letter at all, which is the
    // one thing the box must never say by mistake.
    const MODES = ["is-empty", "is-voice", "is-face", "is-text"];
    const STATES = ["is-present", "is-live", "is-absent"];
    let mode = "empty";
    let src = "";

    const setLetter = (nextMode: string, nextState: string) => {
      if (!box) return;
      box.classList.remove(...MODES, ...STATES);
      box.classList.add(`is-${nextMode}`, `is-${nextState}`);
      mode = nextMode;
    };

    // Which element the current mode is actually driving. Everything that acts
    // on "the media" goes through here, so play, replay and teardown can never
    // disagree about what they are addressing.
    const current = (): HTMLMediaElement | null =>
      mode === "face" ? video : mode === "voice" ? audio : null;

    // Pausing alone leaves the last frame of the previous person frozen on
    // screen and the file still downloading. Dropping the src and calling
    // load() is what actually stops the transfer and blanks the picture.
    const stopMedia = () => {
      for (const m of [video, audio]) {
        if (!m) continue;
        m.pause();
        if (m.getAttribute("src")) {
          m.removeAttribute("src");
          m.load();
        }
      }
    };

    const showLetter = (el: HTMLElement) => {
      if (!box) return;
      // `dataset.letterKind`, and the spelling is the whole story. Renaming the
      // frame to the letter box rewrote `dataset.frame` into `dataset.letterbox`
      // along with every class — but the row's attribute is `data-letter-kind`,
      // so this read `undefined` for every row in the list and the box has shown
      // nothing at all since. Nothing caught it because the tests assert on what
      // the SERVER renders, which was correct the whole time. A rename is not a
      // safe operation on a string that crosses a boundary.
      const nextMode = el.dataset.letterKind || "empty";
      const nextSrc = el.dataset.media || "";
      const nextState = el.dataset.state || "present";
      const nextBody = el.dataset.body || "";

      // Re-selecting the row that is already playing must not restart it.
      if (mode === nextMode && src === nextSrc) {
        setLetter(nextMode, nextState);
        return;
      }

      stopMedia();
      setLetter(nextMode, nextState);
      // THE WORDS THEMSELVES, for a letter that is only words. A real letter
      // box takes letters, and the two kinds that play were the only ones this
      // one would hold. Set before the media branch returns, because a text
      // letter has nothing to play and leaves by that door.
      if (words) words.textContent = nextBody;
      src = nextSrc;
      // A new person has arrived, so the previous one's finished-clip control
      // must go with them.
      box.classList.remove("is-ended");

      const media = current();
      if (!media || !nextSrc) return;

      media.src = nextSrc;

      // ASK BEFORE PLAYING, rather than play and handle the refusal. Catching
      // the rejection was the wrong shape: on iOS a clip that has already been
      // refused unmuted does not reliably start when you set muted and call
      // play() again — the decision is made at the first call. So the state is
      // read UP FRONT and the right call is made once.
      //
      // A face with no activation yet plays MUTED, which is always permitted,
      // so you see the person immediately; the first press unmutes it. A voice
      // is left alone — silent audio is nothing at all, so it keeps its sound
      // and takes the replay control if the browser says no.
      const activated = navigator.userActivation ? navigator.userActivation.hasBeenActive : true;
      media.muted = nextMode === "face" && !activated;

      // AUTOPLAY WITH SOUND NEEDS A USER ACTIVATION, and a scroll is not one —
      // on a phone especially, flicking the list to settle a row is not a
      // gesture the browser will accept. That is policy, not a failure.
      //
      // What was wrong was the response to it. A refusal used to show the
      // replay control and stop, which left a FACE sitting frozen: the person
      // is right there, the clip is loaded, and nothing moves until you tap.
      // So a face retries MUTED — you see them immediately, which is most of
      // what a face is for — and unmutes itself the moment any real gesture
      // arrives. A VOICE gets no such fallback, because silent audio is
      // nothing at all; it keeps the replay control, which is the honest offer.
      media.play().catch(() => {
        if (src !== nextSrc) return;
        // Belt and braces for a browser with no userActivation API: a face that
        // is still refused falls back to muted, a voice offers the replay.
        if (nextMode !== "face") {
          box.classList.add("is-ended");
          return;
        }
        media.muted = true;
        media.play().catch(() => box.classList.add("is-ended"));
      });
    };

    const hideLetter = () => {
      if (!box) return;
      stopMedia();
      setLetter("empty", "present");
      src = "";
      box.classList.remove("is-ended");
    };

    // A clip that runs out has not gone away — the person is still selected and
    // the letter box still theirs, so it keeps the last picture and offers the clip
    // again rather than blanking.
    for (const m of [video, audio]) {
      m?.addEventListener("ended", () => box?.classList.add("is-ended"));
    }

    restart?.addEventListener("click", (e) => {
      // The letter box beneath toggles size on click. Replay is a different intent
      // that happens to live inside it, so it must not also resize.
      e.stopPropagation();
      const media = current();
      if (!media) return;
      media.currentTime = 0;
      media.play().catch(() => {});
      box?.classList.remove("is-ended");
    });

    // ── OPENING A BOX ───────────────────────────────────────────────────────
    // ONE TOGGLE FOR ALL THREE, and it used to be the letter box's alone. That
    // was right while it was the only box holding more than it could show; the
    // doing box truncates somebody's own typing and the mood box knows a family
    // it has no room to name, so all three have a second reading now.
    //
    // A CLASS, AND ONLY A CLASS. The size lives in one attribute and CSS decides
    // what that is worth in pixels — which is also what lets the OTHER boxes get
    // out of the way in the stylesheet rather than here.
    //
    // ONE AT A TIME. Opening a second while the first is open would leave two
    // 18rem boxes fighting over a rail that fits one, so taking a box closes
    // whichever was already taken.
    const boxes = () =>
      Array.from(document.querySelectorAll<HTMLElement>(".scope-boxes .around-box, #letterbox"));

    const label = (el: HTMLElement, open: boolean) => {
      const what = el.id === "letterbox" ? "the letter" : el.dataset.opens || "it";
      el.setAttribute("aria-label", `${open ? "Collapse" : "Expand"} ${what}`);
    };

    const toggleExpand = (el: HTMLElement) => {
      const open = !el.classList.contains("is-expanded");
      for (const other of boxes()) {
        other.classList.remove("is-expanded");
        label(other, false);
      }
      if (open) {
        el.classList.add("is-expanded");
        label(el, true);
      }
    };

    // DELEGATED FROM THE CLUSTER, because the two new boxes are patched by the
    // server on every settle — a listener bound per box at mount would be bound
    // to elements that are no longer in the page a scroll later. The letter box
    // survives patches and could have kept its own; one path for all three is
    // fewer things to keep in step.
    const cluster = document.querySelector<HTMLElement>(".scope-boxes");
    const onBoxPress = (e: Event) => {
      const el = (e.target as HTMLElement).closest?.(".around-box, #letterbox") as HTMLElement | null;
      // Replay is a different intent that happens to live inside the box, and so
      // is putting a caret in a field.
      if (!el || (e.target as HTMLElement).closest?.(".letterbox-restart")) return;
      if (writing(e.target)) return;
      toggleExpand(el);
    };
    cluster?.addEventListener("click", onBoxPress);
    // role="button" earns a keyboard, and a keyboard expects both of these.
    // ── AND NOT WHILE SOMEBODY IS WRITING ───────────────────────────────────
    // role="button" earns a keyboard and a keyboard expects Enter and Space to
    // press. Then a TEXTAREA moved inside one of these boxes, and those are the
    // two keys writing is made of: every space and every line break was caught
    // here and preventDefault'd, so the doing field silently ate them —
    // "mending the fence" came out "mendingthefence" and Return did nothing at
    // all. The symptom looked like a broken input; the cause was a listener two
    // elements up claiming keys it had every right to before the box had
    // anything in it you could type into.
    const writing = (el: EventTarget | null) =>
      !!(el as HTMLElement)?.closest?.("input, textarea, [contenteditable]");

    cluster?.addEventListener("keydown", (e) => {
      if (e.key !== "Enter" && e.key !== " ") return;
      if (writing(e.target)) return;
      const el = (e.target as HTMLElement).closest?.(".around-box, #letterbox") as HTMLElement | null;
      if (!el) return;
      e.preventDefault();
      toggleExpand(el);
    });

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
      const head = el.querySelector<HTMLElement>(".frame-head");
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
        hideLetter();
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
      showLetter(el);
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
        hideLetter();
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
    const INSIDE = "#round-form, .round-picker, .app-foot, .scope-boxes";
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

    // THE FRAME STOPS WHEN THE PANEL OPENS, and this is why it takes an observer
    // rather than a line of CSS. The letter box answers the BAND, and once the band
    // has been picked up and turned into a header there is no band left for it
    // to answer — so app.css hides it. But HIDING A MEDIA ELEMENT DOES NOT
    // SILENCE IT: `visibility: hidden`, `display: none` and removal from the
    // tree all leave a <video> playing, and the result would be a voice coming
    // out of nowhere over an open panel, with no visible thing to press to stop
    // it. So the class that hides it also has to tear the media down.
    //
    // The class arrives on #scopes from the server, and a hook is told about
    // patches to its OWN element, not to the root three levels above it.
    // Watching the attribute is the one way to hear about it.
    let wasOpen = root.classList.contains("is-open");
    const watchPanel = new MutationObserver(() => {
      const open = root.classList.contains("is-open");
      if (open === wasOpen) return;
      wasOpen = open;
      // Closing puts back what the selection still says is chosen, so coming
      // out of the panel does not leave an empty box beside a settled row.
      if (open) hideLetter();
      else {
        const focused = rows().find((i) => i.classList.contains("is-focused"));
        if (focused) showLetter(focused);
      }
    });
    watchPanel.observe(root, { attributes: true, attributeFilter: ["class"] });

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
      showLetter(focused);
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
