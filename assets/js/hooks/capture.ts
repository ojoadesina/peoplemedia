// A FRAME DOES NOT WEAR ITS SCRIM UNTIL THERE IS A PICTURE UNDER IT.
//
// The scrim is a black ramp laid over a capture so the name stays readable on
// it, and the name is drawn light for the same reason. Both were applied the
// moment the server said "this person has a face" — which is a claim about the
// DATABASE, not about anything that has painted. A clip that is slow, blocked or
// simply gone left the ramp lying on nothing: a dark block with no picture in it,
// which is the worst of both, because it is neither the capture nor the ordinary
// empty frame.
//
// SO THE CLIENT ANSWERS IT, because only the client can. `is-ready` goes on when
// the media has actually decoded a frame, and the scrim and the light ink hang
// off that class in CSS. Until then the block is exactly what an uncaptured frame
// is, which is the honest thing for it to be.
type Ctx = { el: HTMLElement; onReady: () => void; media: HTMLElement | null };

export const Capture = {
  mounted(this: Ctx) {
    this.media = this.el.querySelector<HTMLElement>("video, img");
    if (!this.media) return;

    this.onReady = () => this.el.classList.add("is-ready");

    // A cached image or a clip that has already buffered fires nothing, so the
    // state is asked for as well as listened for.
    const el = this.media as HTMLImageElement & HTMLVideoElement;
    if (el.complete || el.readyState >= 2) this.onReady();

    // `loadeddata` rather than `loadedmetadata`: metadata means the browser knows
    // the clip's shape, not that it has a frame to show.
    this.media.addEventListener("loadeddata", this.onReady);
    this.media.addEventListener("load", this.onReady);
  },

  destroyed(this: Ctx) {
    this.media?.removeEventListener("loadeddata", this.onReady);
    this.media?.removeEventListener("load", this.onReady);
  },
};
