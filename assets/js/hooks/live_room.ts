// THE LIVE ROOM. A grid of the people whose line is open right now, and one
// set of brackets — the RETICLE — that glides between them, resting on whoever
// is speaking. That single moving frame is the whole idea: attention in a real
// room is one thing that moves, not every face outlined at once. Every call app
// boxes all of them; this one looks at whoever is talking.
//
// Here there is no microphone to listen to, so the speaker is chosen for the
// demo — a random one of the people who CAN speak (a voice or a face, never an
// open-but-silent line), held for a beat, then the reticle moves on. When the
// real signal exists, this is the one place that changes: pick by loudness
// instead of by dice, and the brackets already know how to fly.
//
// IT PAGES, because a room is not a list. Twenty open lines shrunk to fit one
// screen gives twenty faces too small to recognise, which defeats the point of
// showing faces at all. A page holds as many as can be seen properly — fewer on
// a phone — and the rest wait their turn. Paging happens HERE rather than on the
// server because a page turn is a way of LOOKING at the room, not a change to
// who is in it — asking the server to re-render the grid to see the next three
// faces would throw away the playing videos and the reticle mid-flight to say
// something the browser already knew.
type HookCtx = { el: HTMLElement; cleanup?: () => void; relayout?: () => void };

const PHONE = "(max-width: 40rem)";

export const LiveRoom = {
  mounted(this: HookCtx) {
    const root = this.el;
    const reticle = root.querySelector<HTMLElement>(".live-reticle");
    const stage = reticle?.parentElement ?? null; // the positioned grid
    const cells = Array.from(root.querySelectorAll<HTMLElement>(".live-cell"));
    const pager = root.querySelector<HTMLElement>(".live-pager");
    const label = root.querySelector<HTMLElement>(".live-page");
    const prev = root.querySelector<HTMLButtonElement>(".live-prev");
    const next = root.querySelector<HTMLButtonElement>(".live-next");
    if (!reticle || !stage || !cells.length) return;

    // Six reads as a room on a wide screen (three across, two deep); four is
    // what a phone can show at a size where a face is still a face.
    const perPage = () => (window.matchMedia(PHONE).matches ? 4 : 6);
    const pages = () => Math.max(1, Math.ceil(cells.length / perPage()));
    let page = 0;
    let idx = 0;
    let timer: number | undefined;

    // ONLY WHAT IS ON SCREEN CAN BE LOOKED AT. The reticle picks from the
    // current page, so it never flies off to someone three pages away — and a
    // page with nobody able to speak simply keeps the brackets away.
    const speakers = () => cells.filter((c) => !c.hidden && c.dataset.speaks === "true");

    // Lay the reticle over a cell's FRAME (not the whole cell, which carries the
    // name below it), measured against the grid it lives in. Every frame is the
    // same size, so only the transform actually changes between speakers — which
    // is exactly what the CSS transition rides.
    const place = (cell: HTMLElement, animate: boolean) => {
      const frame = cell.querySelector<HTMLElement>(".live-frame");
      if (!frame) return;
      const fr = frame.getBoundingClientRect();
      const gr = stage.getBoundingClientRect();
      if (!animate) reticle.style.transition = "none";
      reticle.style.width = `${fr.width}px`;
      reticle.style.height = `${fr.height}px`;
      reticle.style.transform = `translate(${Math.round(fr.left - gr.left)}px, ${Math.round(fr.top - gr.top)}px)`;
      if (!animate) {
        void reticle.offsetHeight; // commit the jump before the transition returns
        reticle.style.transition = "";
      }
    };

    const render = (animate: boolean) => {
      const n = perPage();
      const total = pages();
      page = Math.min(page, total - 1);
      const start = page * n;
      cells.forEach((c, i) => {
        c.hidden = i < start || i >= start + n;
      });

      // ONE PAGE IS NOT A PAGER. Controls that can never do anything are just
      // furniture, so they are absent rather than sitting there greyed out.
      if (pager) pager.hidden = total < 2;
      if (label) label.textContent = `${page + 1}/${total}`;
      if (prev) prev.disabled = page === 0;
      if (next) next.disabled = page >= total - 1;

      const live = speakers();
      reticle.hidden = live.length === 0;
      if (live.length) {
        idx = Math.min(idx, live.length - 1);
        place(live[idx], animate);
      }
    };

    // Move to a DIFFERENT speaker each time, so the reticle never appears to
    // stall on the person it is already watching.
    const step = () => {
      const live = speakers();
      if (live.length) {
        let nextIdx = idx;
        if (live.length > 1) {
          while (nextIdx === idx) nextIdx = Math.floor(Math.random() * live.length);
        }
        idx = nextIdx;
        place(live[idx], true);
      }
      timer = window.setTimeout(step, 1300 + Math.random() * 1300);
    };

    const turn = (by: number) => {
      page = Math.max(0, Math.min(pages() - 1, page + by));
      idx = 0;
      // A page change is a JUMP, not a glide: flying the brackets across a grid
      // whose occupants all just changed would be tracking nobody.
      render(false);
    };
    prev?.addEventListener("click", () => turn(-1));
    next?.addEventListener("click", () => turn(1));

    // First placement is a jump, not a glide — there is nowhere for it to fly
    // FROM. Wait a frame so the grid has laid out and the frames have real
    // rects to measure.
    requestAnimationFrame(() => {
      render(false);
      timer = window.setTimeout(step, 1000);
    });

    // A rotation can change how many fit, which changes how many pages there
    // are — and the reticle has to be re-measured against the new geometry.
    const onResize = () => render(false);
    window.addEventListener("resize", onResize);

    // The room is server-rendered and hook-arranged: who is live comes down in a
    // patch, where the reticle rests and how many pages there are do not. So a
    // patch is re-measured rather than exempted.
    this.relayout = () => requestAnimationFrame(() => render(false));

    this.cleanup = () => {
      window.clearTimeout(timer);
      window.removeEventListener("resize", onResize);
    };
  },

  updated(this: HookCtx) {
    this.relayout?.();
  },

  destroyed(this: HookCtx) {
    this.cleanup?.();
  },
};
