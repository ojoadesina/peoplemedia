// A FRAME OPENS INTO ITSELF.
//
// Pressed, the block grows and whatever was captured in it plays. There is no
// room to walk into and no overlay to dismiss, because the frame is already the
// right shape for its contents — opening it is a matter of giving it more of the
// page rather than moving what is in it somewhere else.
//
// THE STATE IS THE CLIENT'S AND SO IS THE CLASS. Which frame is open depends on
// what somebody pressed a moment ago, which is a fact about one browser; the
// server renders every frame closed because that is all it can honestly say, and
// `JS.ignore_attributes(["class"])` on the element is what stops a patch putting
// that answer back over this one.
//
// ONE AT A TIME. Two open frames are two clips playing at once out of one page,
// which is a page nobody can listen to. Opening any frame closes the rest —
// including the ones this hook is not mounted on, which is why the sweep goes
// through the document rather than through anything this instance holds.
type FrameCtx = {
  el: HTMLElement;
  onPress: (e: Event) => void;
  onKey: (e: KeyboardEvent) => void;
  onTime?: () => void;
};

const media = (el: HTMLElement) => el.querySelector<HTMLMediaElement>("video, audio");

const close = (el: HTMLElement) => {
  el.classList.remove("is-open", "is-playing");
  el.style.removeProperty("--played");
  const clip = media(el);
  if (!clip) return;
  clip.pause();
  // BACK TO THE START, not to wherever it stopped. A frame you open again opens
  // at the beginning, because the alternative is a clip that resumes from a
  // point you have no way of seeing and did not choose.
  clip.currentTime = 0;
};

const closeEverything = (except?: HTMLElement) =>
  document
    .querySelectorAll<HTMLElement>(".frame.is-open")
    .forEach((el) => el !== except && close(el));

export const Frame = {
  mounted(this: FrameCtx) {
    // An empty frame has nothing behind it, so it does not open and does not
    // pretend it might — no press target, no keyboard role, no cursor.
    if (this.el.dataset.kind === "empty") return;

    const toggle = () => {
      const opening = !this.el.classList.contains("is-open");
      closeEverything(this.el);
      if (!opening) return close(this.el);

      this.el.classList.add("is-open");
      const clip = media(this.el);
      // A CAPTURE MAY HAVE NO FILE YET — frames are captured and there is nothing
      // to capture with, so most of these are a shape with no clip behind it. The
      // panel still opens: what is being settled here is the design, and a frame
      // that refused to open until the recorder existed could not be looked at.
      if (!clip?.getAttribute("src")) return;
      this.el.classList.add("is-playing");
      void clip.play().catch(() => this.el.classList.remove("is-playing"));
    };

    this.onPress = () => toggle();
    // SPACE AND RETURN, because this is a `role="button"` and a button answers
    // both. Space would otherwise scroll the page out from under the thing that
    // was just pressed.
    this.onKey = (e: KeyboardEvent) => {
      if (e.key !== "Enter" && e.key !== " ") return;
      e.preventDefault();
      toggle();
    };

    this.el.addEventListener("click", this.onPress);
    this.el.addEventListener("keydown", this.onKey);

    // ── HOW FAR THROUGH ──────────────────────────────────────────────────────
    // A fraction, written to `--played`, which the hairline at the panel's foot
    // is the width of. The same custom property the panel's stage already uses,
    // so the two readouts cannot drift apart.
    //
    // A DURATION IS NOT ALWAYS A NUMBER. A stream has none and a file has none
    // until its metadata lands, and dividing by either gives NaN — which as a
    // percentage is a line the browser silently declines to draw. Guarded, the
    // line simply waits.
    const clip = media(this.el);
    if (!clip) return;

    this.onTime = () => {
      const { currentTime, duration } = clip;
      if (!Number.isFinite(duration) || duration <= 0) return;
      this.el.style.setProperty("--played", `${(currentTime / duration) * 100}%`);
    };
    clip.addEventListener("timeupdate", this.onTime);
    // AND THE END IS NOT A CLOSE. The panel stays open with the capture still in
    // it — you asked to see this person's frame, not to watch it once — so only
    // the line goes out. Pressing again plays it from the start.
    clip.addEventListener("ended", () => this.el.classList.remove("is-playing"));
  },

  destroyed(this: FrameCtx) {
    this.el.removeEventListener("click", this.onPress);
    this.el.removeEventListener("keydown", this.onKey);
    if (this.onTime) media(this.el)?.removeEventListener("timeupdate", this.onTime);
  },
};
