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
};

export const Scopes = {
  mounted(this: HookCtx) {
    const scroll = this.el;
    const push = this.pushEvent.bind(this);
    // THE TRANSIENT CLASSES LIVE ON THE SCROLLER, not on #scopes, and that is
    // not a preference. #scopes is the LiveView root: every patch rewrites its
    // class attribute back to whatever the server rendered, so a hook-set
    // `has-selection` survived only until the next update — which is why the
    // frame vanished and the placeholder came back the moment an item was
    // picked. The scroller carries phx-update="ignore", so it is the one
    // element in the tree LiveView will not touch. The CSS reaches the bar from
    // here with a sibling combinator.
    const items = Array.from(scroll.querySelectorAll<HTMLElement>(".scopes-item"));
    const root = document.getElementById("scopes");
    if (!root || !items.length) return;

    // THE FRAME is ONE element that every row borrows in turn, rather than one
    // frame per row: nineteen <video> tags would each hold a buffer for a
    // picture nobody is looking at. The cost of sharing is that the media must
    // be torn down on the way out as deliberately as it is set up on the way in.
    const frame = document.getElementById("frame");
    const video = frame?.querySelector<HTMLVideoElement>(".frame-video") ?? null;
    const audio = frame?.querySelector<HTMLAudioElement>(".frame-audio") ?? null;
    const restart = frame?.querySelector<HTMLButtonElement>(".frame-restart") ?? null;

    // THE FRAME'S STATE IS CLASSES, NOT DATA ATTRIBUTES, and that is forced by
    // LiveView rather than chosen: on a patched element it strips a client-set
    // src, and on an ignored one it still merges data-* from the server's copy
    // and deletes any the client added. Classes it leaves alone in both cases,
    // so the frame keeps its own mind across a re-render. `mode` is tracked in a
    // plain variable because reading it back out of a class list would be
    // guessing at what we ourselves wrote.
    const MODES = ["is-empty", "is-voice", "is-face"];
    const STATES = ["is-present", "is-live", "is-absent"];
    let mode = "empty";
    let src = "";

    const setFrame = (nextMode: string, nextState: string) => {
      if (!frame) return;
      frame.classList.remove(...MODES, ...STATES);
      frame.classList.add(`is-${nextMode}`, `is-${nextState}`);
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

    const showFrame = (el: HTMLElement) => {
      if (!frame) return;
      const nextMode = el.dataset.frame || "empty";
      const nextSrc = el.dataset.media || "";
      const nextState = el.dataset.state || "present";

      // Re-selecting the row that is already playing must not restart it.
      if (mode === nextMode && src === nextSrc) {
        setFrame(nextMode, nextState);
        return;
      }

      stopMedia();
      setFrame(nextMode, nextState);
      src = nextSrc;
      // A new person has arrived, so the previous one's finished-clip control
      // must go with them.
      frame.classList.remove("is-ended");

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
          frame.classList.add("is-ended");
          return;
        }
        media.muted = true;
        media.play().catch(() => frame.classList.add("is-ended"));
      });
    };

    const hideFrame = () => {
      if (!frame) return;
      stopMedia();
      setFrame("empty", "present");
      src = "";
      frame.classList.remove("is-ended");
    };

    // A clip that runs out has not gone away — the person is still selected and
    // the frame still theirs, so it keeps the last picture and offers the clip
    // again rather than blanking.
    for (const m of [video, audio]) {
      m?.addEventListener("ended", () => frame?.classList.add("is-ended"));
    }

    restart?.addEventListener("click", (e) => {
      // The frame beneath toggles size on click. Replay is a different intent
      // that happens to live inside it, so it must not also resize.
      e.stopPropagation();
      const media = current();
      if (!media) return;
      media.currentTime = 0;
      media.play().catch(() => {});
      frame?.classList.remove("is-ended");
    });

    // EXPAND is a toggle on the frame itself, so the size lives in one
    // attribute and CSS decides what that is worth in pixels.
    const toggleExpand = () => {
      if (!frame) return;
      const open = frame.classList.toggle("is-expanded");
      frame.setAttribute("aria-label", open ? "Collapse frame" : "Expand frame");
    };

    frame?.addEventListener("click", toggleExpand);
    // role="button" earns a keyboard, and a keyboard expects both of these.
    frame?.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        toggleExpand();
      }
    });

    let settleTimer: number | undefined;
    // A snap scrolls, which settles, which may snap again. Bounded, so a snap
    // the scroller cannot actually perform (already at either end) gives up
    // instead of retrying forever.
    let snaps = 0;

    const rowHeight = () => items[0].getBoundingClientRect().height;

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

    // The nearest row and how far it is from the band, signed: positive means
    // the row sits below the band, so scrolling down by that much lifts it in.
    const nearest = (): { el: HTMLElement; delta: number } | null => {
      const centre = bandCentre();
      let best: { el: HTMLElement; delta: number } | null = null;
      for (const el of items) {
        const r = el.getBoundingClientRect();
        const delta = r.top + r.height / 2 - centre;
        if (!best || Math.abs(delta) < Math.abs(best.delta)) best = { el, delta };
      }
      return best;
    };

    const clear = () => items.forEach((i) => i.classList.remove("is-focused"));

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
        hideFrame();
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

    const take = (el: HTMLElement) => {
      clear();
      el.classList.add("is-focused");
      scroll.classList.add("has-selection");
      showFrame(el);
      report(items.indexOf(el));
    };

    scroll.addEventListener(
      "scroll",
      () => {
        // Moving: no selection, no line, and no placeholder either — a row is
        // passing through the band and they would collide.
        scroll.classList.add("is-scrolling");
        scroll.classList.remove("has-selection");
        clear();
        // The frame leaves with the selection. Sound continuing over a moving
        // list would be a voice with nobody attached to it.
        hideFrame();
        window.clearTimeout(settleTimer);
        settleTimer = window.setTimeout(settle, 140);
      },
      { passive: true },
    );

    // Tapping a row is the same act as scrolling it in — it travels to the band
    // and the band decides, rather than being selected behind the band's back.
    items.forEach((el) =>
      el.addEventListener("click", () => {
        const r = el.getBoundingClientRect();
        scroll.scrollBy({ top: r.top + r.height / 2 - bandCentre(), behavior: "smooth" });
      }),
    );

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
    // rather than a line of CSS. The frame answers the BAND, and once the band
    // has been picked up and turned into a header there is no band left for it
    // to answer — so app.css hides it. But HIDING A MEDIA ELEMENT DOES NOT
    // SILENCE IT: `visibility: hidden`, `display: none` and removal from the
    // tree all leave a <video> playing, and the result would be a voice coming
    // out of nowhere over an open panel, with no visible thing to press to stop
    // it. So the class that hides it also has to tear the media down.
    //
    // The class arrives on #scopes from the server, and this hook cannot see
    // server patches — it lives on the scroller, which is phx-update="ignore".
    // Watching the attribute is the one way to hear about it.
    let wasOpen = root.classList.contains("is-open");
    const watchPanel = new MutationObserver(() => {
      const open = root.classList.contains("is-open");
      if (open === wasOpen) return;
      wasOpen = open;
      // Closing puts back what the selection still says is chosen, so coming
      // out of the panel does not leave an empty box beside a settled row.
      if (open) hideFrame();
      else {
        const focused = items.find((i) => i.classList.contains("is-focused"));
        if (focused) showFrame(focused);
      }
    });
    watchPanel.observe(root, { attributes: true, attributeFilter: ["class"] });

    window.addEventListener("resize", settle);
    // A frame's grace so the flex layout has resolved a real height to measure.
    requestAnimationFrame(() => requestAnimationFrame(settle));

    this.cleanup = () => {
      watchPanel.disconnect();
      document.removeEventListener("pointerdown", unhush);
      window.removeEventListener("resize", settle);
    };
  },

  // Swapping the list re-mounts this hook, so the old one's observer and its two
  // document-level listeners have to go with it or they accumulate one set per
  // switch, each holding a dead scroller.
  destroyed(this: HookCtx) {
    this.cleanup?.();
  },
};
