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
// ── AND THE BAND'S OTHER FACES ───────────────────────────────────────────────
// The bar is also a three-page track: the PLACE picker, the POPULATION toggle,
// and the band itself. The geometry is all CSS; what is here is only what CSS
// cannot say — which page it opens on, that pressing an empty band turns it
// over, that a press inside a drawer hands the list back, and that being on the
// place page IS being in the place picker.
const HEADER_TOP = 32; // 2rem of air above the header, per the design

// THREE PAGES, LEFT TO RIGHT: the PLACE picker, the POPULATION toggle, and the
// band itself. The band rests on the last of them, so one swipe right reaches
// the population and two reach the place — the rarer decision is the further
// gesture.
const PLACE = 0;
const SCOPE = 1;
const FACE = 2;

const pageOf = (el: HTMLElement) =>
  el.clientWidth ? Math.round(el.scrollLeft / el.clientWidth) : FACE;

// A scroller opens at its start edge, and the start edge here is the place, so
// parking it on the face is a write rather than a declaration.
//
// TWICE, AND THE SECOND TIME IS THE ONE THAT WORKS. On a fresh node the pages may
// not be laid out yet, which makes `scrollWidth` equal to the visible width;
// asking to scroll there is asking to scroll to zero, and the clamp is silent. A
// frame later the pages exist and the same call means what it says.
const goTo = (el: HTMLElement, page: number, smooth = false) => {
  const go = () =>
    el.scrollTo({
      left: page === FACE ? el.scrollWidth : page * el.clientWidth,
      behavior: smooth ? "smooth" : "auto",
    });
  go();
  if (!smooth) requestAnimationFrame(go);
};

const face = (el: HTMLElement, smooth = false) => goTo(el, FACE, smooth);

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

    // WHICH PAGE IT IS ON IS REMEMBERED, and it has to be. A patch that changes
    // any sibling's id makes morphdom take this node out and put it back — the
    // element survives, the hook is not re-mounted, and NOTHING says anything has
    // happened, but re-inserting a scroll container resets its offset to zero. So
    // the drawer flew open by itself every time the list changed mode.
    //
    // Restoring the REMEMBERED page rather than always the face is what keeps
    // that repair from becoming its own bug: a patch arrives on this surface for
    // reasons that have nothing to do with the band, and slamming the settings
    // shut under the hand of somebody reading them would be no better.
    this.page = FACE;
    face(this.el);

    // ── PRESSING AN EMPTY BAND TURNS IT OVER ─────────────────────────────────
    // With somebody in it, a press picks them up — that is `toggle_open`, and it
    // stays. With nobody in it the same press does nothing at all, which leaves
    // the largest target on the page inert; the settings are what it should have
    // been doing, and reaching them by press rather than by swipe is what makes
    // them findable at all.
    //
    // IT OPENS THE NEARER DRAWER, not the furthest. One swipe's worth, so the
    // press and the gesture agree about what "open the settings" means.
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

      // A CONTROL IN A DRAWER COMMITS AND HANDS THE LIST BACK. Whatever you came
      // in to change is changed by the time the press lands, so keeping the
      // drawer up would leave you reading a setting instead of the result of it.
      // The press itself goes through untouched — this only decides where the
      // track ends up afterwards.
      if (target?.closest?.(".list-tags")) {
        this.page = FACE;
        requestAnimationFrame(() => face(this.el, true));
        return;
      }

      if (!target?.closest?.(".focus-box")) return;
      if (pageOf(this.el) !== FACE) return;
      const list = this.el.parentElement?.querySelector<HTMLElement>(".scopes-scroll");
      if (list?.classList.contains("has-selection")) return; // filled: pick it up
      e.stopPropagation();
      e.preventDefault();
      this.page = SCOPE;
      goTo(this.el, SCOPE, true);
    };
    this.el.addEventListener("click", this.onPress, true);

    // ── THE PLACE DRAWER IS THE PLACE MODE ───────────────────────────────────
    // Opening it turns the LIST into a roll of countries and closing it puts back
    // what was there. That is what makes the swipe worth making: the drawer is
    // not a form you fill in and submit, it is the mode, and you are in it
    // exactly as long as it is up.
    //
    // IT USED TO TAKE A PRESS TO GET IN AND A CANCEL TO GET OUT, both of which
    // stood in the drawer beside the place — fine while these lived on a line
    // above the list, always in view. Behind the band the way out went with them:
    // swipe back and the list was still every country in the world, with its
    // cancel now hidden, no name on screen, and nothing to say what had happened
    // to your people.
    //
    // IT ASKS THE DOM RATHER THAN KEEPING A FLAG, because the server owns whether
    // the picker is open and says so on the bar. A flag here would be a second
    // copy of that answer, free to drift from it.
    let idle: number;
    this.onSettle = () => {
      clearTimeout(idle);
      idle = setTimeout(() => {
        this.page = pageOf(this.el);
        const open = this.el.dataset.placeOpen === "true";
        if (this.page === PLACE && !open) this.pushEvent("place_box", {});
        if (this.page !== PLACE && open) this.pushEvent("cancel_place", {});
      }, 140) as unknown as number;
    };
    this.el.addEventListener("scroll", this.onSettle, { passive: true });

    // A resize moves the band, and with it the distance left to travel — and it
    // resizes the pages under the scroll offset, which would otherwise leave the
    // track parked between the two.
    this.onResize = () => {
      this.sync();
      goTo(this.el, this.page);
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
  updated(this: { el: HTMLElement; page: number; sync: () => void }) {
    this.sync();

    // A PICKED BAND ALWAYS SHOWS ITS FACE, whatever page it was on — it is flying
    // up to become the header of a room opening under it, and arriving there
    // turned over would make the header the label of the wrong thing.
    if (this.el.classList.contains("is-picked")) {
      this.page = FACE;
      face(this.el, true);
    } else {
      // Otherwise: put it back where the reader left it. See the note at mount —
      // a patch can move this node, and a moved scroller loses its offset.
      goTo(this.el, this.page);
    }
  },

  destroyed(this: {
    el: HTMLElement;
    onResize: () => void;
    onPress: (e: MouseEvent) => void;
    onSettle: () => void;
  }) {
    window.removeEventListener("resize", this.onResize);
    this.el.removeEventListener("click", this.onPress, true);
    this.el.removeEventListener("scroll", this.onSettle);
  },
};
