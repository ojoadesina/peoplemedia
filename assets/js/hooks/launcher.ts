// THE LAUNCHER — one overlay, many rooms, and a tiny registry joining them.
//
// It is called the launcher rather than the FAB panel, which is what it was:
// naming a thing after the button that opens it says nothing about what is
// inside. It also keeps it apart from THE PANEL, which opens under the header
// when a relationship is picked up. That one is about a person; this one is
// about the app — the passport, scoping, whatever comes next.
//
// THE REGISTRY IS THE WHOLE DESIGN. Every body carries `data-room="x"`;
// anything carrying `data-open-room="x"` opens it. Adding a room later is
// markup — one cell in the launcher, one body — and no new JavaScript. Ported
// from the project this app grew out of, where the same eight lines carried
// search, passport, scoping, voices and places.
//
// `mode` IS THE ONE TRUTH: the name of the open body, or null. Everything else
// on screen is stamped from it.
type HookCtx = {
  el: HTMLElement;
  pushEvent: (event: string, payload: object) => void;
  handleEvent: (event: string, cb: (payload: { room: string | null }) => void) => void;
  cleanup?: () => void;
  restamp?: () => void;
};

export const Launcher = {
  mounted(this: HookCtx) {
    const panel = this.el;
    const push = this.pushEvent.bind(this);
    // THE DOOR IS THE `MORE` BUTTON NOW, not the act. The act was drawn as a
    // plus and opened a drawer, which is two different promises on one press;
    // it writes a letterhead today and reaches this panel the same way every
    // other control does — through the registry below, by naming a room.
    const more = document.getElementById("more");
    // AND THE WHOLE FOOT STEPS ASIDE, not one button of it. There are three down
    // there now, and leaving two behind would put a door to this panel
    // underneath this panel.
    const foot = document.querySelector<HTMLElement>(".app-foot");
    if (!more) return;

    let mode: string | null = null;
    const isOpen = () => mode !== null;

    // ROOMS ARE LOOKED UP FRESH, never captured at mount. The server owns this
    // markup — the launcher changes the moment someone checks in — so a patch
    // can replace these nodes, and a Map built once would then be holding
    // elements that are no longer in the page.
    const room = (name: string) =>
      panel.querySelector<HTMLElement>(`[data-room="${name}"]`);
    const rooms = () => Array.from(panel.querySelectorAll<HTMLElement>("[data-room]"));

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
      if (mode) rooms().forEach((el) => (el.hidden = el.dataset.room !== mode));

      // A closed panel is not there as far as assistive tech is concerned; an
      // open one is the only thing on screen. Saying `aria-hidden` statically
      // would have made every room permanently unreachable.
      panel.setAttribute("aria-hidden", String(!open));

      if (mode) panel.dataset.body = mode;
      else panel.removeAttribute("data-body");

      // THE FOOT OPENS THE LAUNCHER AND THEN GETS OUT OF THE WAY. It used to do
      // all three jobs on one button — plus, cross, arrow — which was a good
      // gesture in the wrong place: it left the way out of a room sitting at the
      // foot of the page, a screen away from the back and forward the room's own
      // form was using. The launcher carries its own master now, in that row.
      foot?.classList.toggle("is-away", open);
      for (const b of foot?.querySelectorAll<HTMLElement>("button") ?? []) {
        b.setAttribute("aria-hidden", String(open));
        b.tabIndex = open ? -1 : 0;
      }
      // Only the door claims to be the thing that expanded.
      more.setAttribute("aria-expanded", String(open));
    };

    const setPanel = (name: string | null) => {
      mode = name;
      stamp();
      // OPENING THE ROOM IS READING WHAT IS IN IT. The server owns the count and
      // cannot see a room being opened — that is entirely a fact about this
      // browser — so it has to be told, or the badge counts things you have
      // already looked at forever.
      if (name === "scoping") push("seen_scoping", {});
      if (!name) return;
      replay(room(name));
      // THE HEAD ANSWERS THE DOOR. Its eyes are drawn on again every time a
      // room opens — the reference's one gesture, and the reason the mark is
      // in here at all rather than just the app's own furniture showing
      // through. Re-query it: the server owns this markup.
      replay(panel.querySelector(".launcher-head .head"));
    };

    // ── The three ways in and out ──────────────────────────────────────────
    // Anything that names a body opens it. Delegated from the document rather
    // than bound per element, so a cell rendered later — by a patch, or by a
    // nested LiveView that cannot reach this hook — works with no wiring.
    const onOpen = (e: Event) => {
      const el = (e.target as HTMLElement).closest?.("[data-open-room]") as HTMLElement | null;
      if (!el) return;
      // A FOOT BUTTON STILL POPS. The act reaches its room through this
      // registry rather than through a handler of its own, so without this the
      // one button people press most would be the only one that felt inert.
      if (foot?.contains(el)) replay(el);
      setPanel(el.dataset.openRoom || null);
    };

    // THE MASTER MEANS ONE THING AND DOES TWO, and only this knows which: at
    // the launcher it closes the panel, in a room it steps back to the
    // launcher. The button itself carries no target — a room that had to name
    // where "back" goes would have to be told, and then the two could disagree.
    const onMaster = (e: Event) => {
      if (!(e.target as HTMLElement).closest?.("[data-launcher-back]")) return;
      setPanel(mode === "launcher" ? null : "launcher");
    };

    // The door: open the launcher, close from it, or step back to it. Stepping
    // back rather than closing is what makes the launcher a place you are in
    // rather than a menu you dismissed.
    const onMore = () => {
      replay(more);
      setPanel(isOpen() ? null : "launcher");
    };

    // ESCAPE unwinds one step at a time, the same way the act does.
    const onKey = (e: KeyboardEvent) => {
      if (e.key !== "Escape" || !isOpen()) return;
      e.preventDefault();
      setPanel(mode === "launcher" ? null : "launcher");
    };

    // WHICH ROOM IS OPEN IS THE BROWSER'S, EXCEPT WHEN IT IS NOT. Opening a
    // room is a press and belongs here; being FINISHED with one is something
    // only the server knows — it is the thing that just wrote the row. Without
    // this the launcher sat in the room you had completed, with its subject
    // cleared, showing the instructions for a task you had already done.
    this.handleEvent("launcher:room", ({ room }) => setPanel(room ?? null));

    document.addEventListener("click", onOpen);
    document.addEventListener("click", onMaster);
    more.addEventListener("click", onMore);
    document.addEventListener("keydown", onKey);

    stamp();
    this.restamp = stamp;

    this.cleanup = () => {
      document.removeEventListener("click", onOpen);
      document.removeEventListener("click", onMaster);
      more.removeEventListener("click", onMore);
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
