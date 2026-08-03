// THE PICK. The band and the frame are already one element — the bar — so
// picking an item up is not a matter of assembling anything, only of moving
// what is there. It travels by TRANSFORM and nothing else, which is not a
// performance choice: the frame inside it may be mid-sentence, and moving a
// <video> in the DOM pauses it. Nothing here touches the tree.
//
// The server owns WHETHER it is picked (the `is-picked` class arrives with a
// patch); this hook owns HOW FAR, because that is a question about the viewport
// that only the client can answer.
//
// ── AND THE BAND'S TWO FACES ─────────────────────────────────────────────────
// The bar is also a two-page track: the list's settings on the first page, the
// band itself on the second. Everything about that is CSS except the two things
// CSS has no way to say — WHICH PAGE IT OPENS ON, and that pressing an empty
// band should turn it over.
const HEADER_TOP = 32; // 2rem of air above the header, per the design

// A scroller opens at its start edge, and the start edge here is the settings.
// Parking it on the face is therefore a write rather than a declaration, and it
// happens at mount and after a resize ONLY: doing it on every patch would shut
// the settings under the hand of somebody reading them, and a patch arrives on
// this surface for reasons that have nothing to do with the band.
const face = (el: HTMLElement, smooth = false) =>
  el.scrollTo({ left: el.scrollWidth, behavior: smooth ? "smooth" : "auto" });

const settings = (el: HTMLElement) => el.scrollTo({ left: 0, behavior: "smooth" });

// Half a page is the line between them, so a track left mid-swipe by a resize
// returns to whichever page it was nearer rather than always to the face.
const showingSettings = (el: HTMLElement) => el.scrollLeft < el.scrollWidth / 4;

export const Bar = {
  mounted(this: { el: HTMLElement }) {
    // ONLY THE DELTA GOES HERE, never the bar's own -50% centring shift.
    // Tailwind v4 writes `-translate-y-1/2` to the `translate` PROPERTY, not to
    // `transform`, and the two compose — `translate` is applied first, then
    // `transform` on top. Repeating the -50% here therefore doubled it and sat
    // the band half its own height above the row it was supposed to be framing.
    // The centring belongs to the class; the travel belongs to this.
    let shift = 0;

    const apply = (px: number) => {
      shift = px;
      this.el.style.transform = px === 0 ? "" : `translateY(${px}px)`;
    };

    // Measured from where it IS, not from where it started, so a resize or a
    // second pick corrects rather than compounds.
    const fly = () => {
      const top = this.el.getBoundingClientRect().top;
      apply(shift + (HEADER_TOP - top));
    };

    const land = () => apply(0);

    this.sync = () => (this.el.classList.contains("is-picked") ? fly() : land());
    this.sync();
    face(this.el);

    // ── PRESSING AN EMPTY BAND TURNS IT OVER ─────────────────────────────────
    // With somebody in it, a press picks them up — that is `toggle_open`, and it
    // stays. With nobody in it the same press does nothing at all, which leaves
    // the largest target on the page inert; the settings are what it should have
    // been doing, and reaching them by press rather than by swipe is what makes
    // them findable at all.
    //
    // WHETHER THE BAND IS EMPTY IS THE CLIENT'S ANSWER, not the server's. It is
    // a fact about where the LIST is scrolled to, which lives in this browser —
    // the same `has-selection` the dots are drawn from, so the band opens the
    // settings exactly when it is showing dots.
    //
    // CAPTURE, AND IT HAS TO BE. LiveView listens for clicks on the document, so
    // stopping this one anywhere below that is what keeps `toggle_open` from
    // also firing. Bubbling from the box would be too late for a listener bound
    // above it; capturing on the bar is early enough to be sure.
    this.onPress = (e: MouseEvent) => {
      const target = e.target as HTMLElement | null;
      if (!target?.closest?.(".focus-box")) return; // a setting, not the band
      if (showingSettings(this.el)) return;
      const list = this.el.parentElement?.querySelector<HTMLElement>(".scopes-scroll");
      if (list?.classList.contains("has-selection")) return; // filled: pick it up
      e.stopPropagation();
      e.preventDefault();
      settings(this.el);
    };
    this.el.addEventListener("click", this.onPress, true);

    // A resize moves the band, and with it the distance left to travel — and it
    // resizes the pages under the scroll offset, which would otherwise leave the
    // track parked between the two.
    this.onResize = () => {
      this.sync();
      if (!showingSettings(this.el)) face(this.el);
    };
    window.addEventListener("resize", this.onResize);
  },

  // The class flips on the server, so the move has to be re-derived after every
  // patch. Cheap: one measurement and one style write.
  //
  // A PICKED BAND SHOWS ITS FACE. It is flying up to become the header of a room
  // that is opening under it, and arriving there turned over — showing a place
  // and a population instead of the name of whoever was picked — would make the
  // header the label of the wrong thing.
  updated(this: { el: HTMLElement; sync: () => void }) {
    this.sync();
    if (this.el.classList.contains("is-picked")) face(this.el, true);
  },

  destroyed(this: { el: HTMLElement; onResize: () => void; onPress: (e: MouseEvent) => void }) {
    window.removeEventListener("resize", this.onResize);
    this.el.removeEventListener("click", this.onPress, true);
  },
};
