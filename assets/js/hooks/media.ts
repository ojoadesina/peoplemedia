/**
 * A media element that keeps playing across a patch.
 *
 * WHAT IS PLAYING IS NOT SOMETHING THE SERVER KNOWS. Which letter the frame is
 * holding depends on where the list has settled, and where the list has settled
 * is a fact about a scroll position in one browser. So the src is set by a hook,
 * and the server renders these elements empty.
 *
 * That used to mean the whole box had to be marked phx-update="ignore", because
 * a patch reconciles the DOM against the server's copy and the server's copy has
 * no src — so the src went, and a face stopped mid-sentence. But ignoring a box
 * to protect two elements inside it freezes the box, and the same reflex applied
 * to the list is what stopped the list from ever changing.
 *
 * So the element carries its own state across the patch instead: what it was
 * playing and how far in, read off before and put back after. The cost is a
 * dropped frame on a patch that arrives mid-clip; the cost of the alternative
 * was everything around it going stale.
 */
type MediaCtx = {
  el: HTMLMediaElement;
  was?: { src: string; at: number; playing: boolean };
};

export const Media = {
  beforeUpdate(this: MediaCtx) {
    const src = this.el.getAttribute("src") || "";
    this.was = src ? { src, at: this.el.currentTime, playing: !this.el.paused } : undefined;
  },

  updated(this: MediaCtx) {
    const was = this.was;
    // Nothing was playing, or the patch left the src alone — either way there is
    // nothing to put back, and re-assigning a src that is already there would
    // reload the clip for no reason.
    if (!was || this.el.getAttribute("src") === was.src) return;

    this.el.setAttribute("src", was.src);
    // The position has to wait for the reloaded source to admit it has one.
    const resume = () => {
      this.el.currentTime = was.at;
      if (was.playing) void this.el.play().catch(() => {});
    };
    if (this.el.readyState >= 1) resume();
    else this.el.addEventListener("loadedmetadata", resume, { once: true });
  },
};
