// THE FAB PANEL — one overlay, many bodies, and a tiny registry joining them.
//
// It is called the FAB panel to keep it apart from THE PANEL, which is what
// opens under the header when a relationship is picked up. That one is about a
// person; this one is about the app — the passport, scoping, whatever comes
// next. Two panels, two jobs, and the names have to say which.
//
// THE REGISTRY IS THE WHOLE DESIGN. Every body carries `data-panel-body="x"`;
// anything carrying `data-panel-open="x"` opens it. Adding a room later is
// markup — one cell in the launcher, one body — and no new JavaScript. Ported
// from the project this app grew out of, where the same eight lines carried
// search, passport, scoping, voices and places.
//
// `mode` IS THE ONE TRUTH: the name of the open body, or null. Everything else
// on screen is stamped from it.
type HookCtx = {
  el: HTMLElement;
  cleanup?: () => void;
  restamp?: () => void;
};

export const FabPanel = {
  mounted(this: HookCtx) {
    const panel = this.el;
    const act = document.getElementById("act");
    if (!act) return;

    let mode: string | null = null;
    const isOpen = () => mode !== null;

    // ROOMS ARE LOOKED UP FRESH, never captured at mount. The server owns this
    // markup — the launcher changes the moment someone checks in — so a patch
    // can replace these nodes, and a Map built once would then be holding
    // elements that are no longer in the page.
    const room = (name: string) =>
      panel.querySelector<HTMLElement>(`[data-panel-body="${name}"]`);
    const rooms = () => Array.from(panel.querySelectorAll<HTMLElement>("[data-panel-body]"));

    // Re-run a CSS entrance animation: remove, force a reflow, put it back.
    // Without the reflow the browser coalesces the two writes and nothing
    // replays — the element never left the state it is being returned to.
    const replay = (el: Element | null) => {
      const h = el as HTMLElement | null;
      if (!h) return;
      h.style.animation = "none";
      void h.offsetWidth;
      h.style.animation = "";
    };

    // STAMP THE WHOLE PANEL FROM `mode`. Pure and idempotent — it reads nothing
    // back out of the DOM and has no side effects, so it is safe to run again
    // after any patch — which `updated/0` at the bottom relies on entirely.
    const stamp = () => {
      const open = isOpen();
      panel.classList.toggle("is-open", open);

      // Rooms are switched only while OPEN. On close the current one stays
      // put, so the accordion rolls up over what you were looking at instead
      // of the content vanishing first and the box closing on nothing.
      if (mode) rooms().forEach((el) => (el.hidden = el.dataset.panelBody !== mode));

      // A closed panel is not there as far as assistive tech is concerned; an
      // open one is the only thing on screen. Saying `aria-hidden` statically
      // would have made every room permanently unreachable.
      panel.setAttribute("aria-hidden", String(!open));

      if (mode) panel.dataset.body = mode;
      else panel.removeAttribute("data-body");

      // THE ACT IS THE ONLY CONTROL. Closed it is a plus; over the launcher it
      // is that same plus turned 45 degrees into a cross; inside a room it is
      // an arrow back to the launcher. One button, three answers, and the thing
      // you pressed is the thing that responds.
      act.classList.toggle("is-open", open);
      act.classList.toggle("is-back", open && mode !== "launcher");
      act.setAttribute("aria-expanded", String(open));
      act.setAttribute(
        "aria-label",
        !open ? "Open the launcher" : mode === "launcher" ? "Close" : "Back to the launcher",
      );
    };

    const setPanel = (name: string | null) => {
      mode = name;
      stamp();
      if (!name) return;
      replay(room(name));
      // THE HEAD ANSWERS THE DOOR. Its eyes are drawn on again every time a
      // room opens — the reference's one gesture, and the reason the mark is
      // in here at all rather than just the app's own furniture showing
      // through. Re-query it: the server owns this markup.
      replay(panel.querySelector(".fab-head .head"));
    };

    // ── The three ways in and out ──────────────────────────────────────────
    // Anything that names a body opens it. Delegated from the document rather
    // than bound per element, so a cell rendered later — by a patch, or by a
    // nested LiveView that cannot reach this hook — works with no wiring.
    const onOpen = (e: Event) => {
      const el = (e.target as HTMLElement).closest?.("[data-panel-open]") as HTMLElement | null;
      if (el) setPanel(el.dataset.panelOpen || null);
    };

    const onClose = (e: Event) => {
      if ((e.target as HTMLElement).closest?.("[data-panel-close]")) setPanel(null);
    };

    // The act: open the launcher, close from it, or step back to it. Stepping
    // back rather than closing is what makes the launcher a place you are in
    // rather than a menu you dismissed.
    const onAct = () => {
      replay(act);
      if (!isOpen()) setPanel("launcher");
      else if (mode === "launcher") setPanel(null);
      else setPanel("launcher");
    };

    // ESCAPE unwinds one step at a time, the same way the act does.
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" || !isOpen()) return;
      e.preventDefault();
      setPanel(mode === "launcher" ? null : "launcher");
    };

    document.addEventListener("click", onOpen);
    document.addEventListener("click", onClose);
    act.addEventListener("click", onAct);
    document.addEventListener("keydown", onKey);

    stamp();
    this.restamp = stamp;

    this.cleanup = () => {
      document.removeEventListener("click", onOpen);
      document.removeEventListener("click", onClose);
      act.removeEventListener("click", onAct);
      document.removeEventListener("keydown", onKey);
    };
  },

  // THE SERVER OWNS THIS MARKUP AND WILL UNDRESS IT. Every patch re-renders the
  // panel from the server's copy, which is always CLOSED — `mode` lives here and
  // the server has never heard of it. Left alone that leaves a ghost: the act
  // still says open and nothing is on screen. Re-stamping after each patch is
  // the whole fix, and it is why `stamp` is pure and idempotent.
  updated(this: HookCtx) {
    this.restamp?.();
  },

  destroyed(this: HookCtx) {
    this.cleanup?.();
  },
};
