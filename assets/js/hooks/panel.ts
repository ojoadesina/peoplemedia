// THE PANEL. The relationship list's own mechanism, one level in: a band a
// third of the way down, letters scrolling THROUGH it, and whichever settles
// there is chosen. What is different is what "chosen" does. There is no frame
// off to the side — the chosen box IS the player.
//
// Two stages, so scrolling the list is never a wall of noise:
//
//   PREVIEW — a letter that lands in the band plays MUTED. A voice breathes
//   the box (the pulse is the play effect); a face shows silently at rest size.
//   Nothing is audible, so you can scroll through a whole conversation in peace.
//
//   COMMIT — clicking the chosen letter is what turns the sound on. A face
//   also grows to full height to be looked at properly; a voice just becomes
//   audible. There is no play/pause control anywhere — the row is the control.
//
// A TEXT LETTER HAS NOTHING TO PLAY, and every path here already handles that
// without a special case: `media()` returns null for any kind that is not
// voice or face, so preview loads nothing and commit does nothing. The box
// keeps its placeholder, which is the honest answer — the words themselves are
// not shown here yet.
//
// It reverts itself. When the media finishes, or the list moves under it, the
// box shrinks back and mutes again. Nothing keeps playing over a moving list,
// and nothing stays enlarged once it is done.
type HookCtx = { el: HTMLElement; cleanup?: () => void };

export const Panel = {
  mounted(this: HookCtx) {
    const scroll = this.el;
    const items = Array.from(scroll.querySelectorAll<HTMLElement>(".panel-item"));
    const stage = scroll.parentElement?.querySelector<HTMLElement>(".stage") ?? null;
    const video = stage?.querySelector<HTMLVideoElement>(".stage-video") ?? null;
    const audio = stage?.querySelector<HTMLAudioElement>(".stage-audio") ?? null;
    if (!items.length || !stage) return;

    // The box's state is CLASSES, not data attributes: it is phx-update="ignore"
    // so a patch never rewrites it, and classes survive a re-render where a
    // client-set src would not. `mode` is a plain variable because reading it
    // back out of the class list would be guessing at what we ourselves wrote.
    //
    //   is-voice / is-face — a presence of that kind is loaded (preview or on).
    //   is-playing         — the media is actually playing; drives the pulse.
    //   is-live            — sound is on and a face is enlarged; the commit.
    let mode = "empty";
    let src = "";

    const setKind = (next: string) => {
      stage.classList.remove("is-voice", "is-face");
      if (next !== "empty") stage.classList.add(`is-${next}`);
      mode = next;
    };
    const media = (): HTMLMediaElement | null =>
      mode === "face" ? video : mode === "voice" ? audio : null;

    // Pausing alone freezes the last frame and leaves the file downloading.
    // Dropping the src and calling load() is what stops the transfer and blanks
    // the box for the next presence.
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

    // PREVIEW: a presence lands READY, not playing. No commit, no sound, no
    // motion — a face shows a still first frame, a voice shows its box, and
    // both wait for the click.
    const preview = (el: HTMLElement) => {
      const nextMode = el.dataset.kind || "empty";
      const nextSrc = el.dataset.media || "";
      if (mode === nextMode && src === nextSrc) return;

      stopMedia();
      // Reset the play effect up front rather than trusting the outgoing clip's
      // 'pause' to land in time — nothing plays on landing, and the box must not
      // inherit the last presence's progress.
      stage.classList.remove("is-live", "is-playing");
      stage.style.setProperty("--played", "0%");
      setKind(nextMode);
      src = nextSrc;

      const m = media();
      if (!m || !nextSrc) return;
      m.src = nextSrc;
      // Ready, paused. Because nothing ever plays until the click — and the click
      // carries the activation sound needs — there is no muting anywhere, and so
      // none to undo. A face's still frame is coaxed out by the loadedmetadata
      // handler below; a voice simply has nothing to show until it is played.
    };

    // COMMIT: the click on the already-chosen presence turns the sound on, and
    // grows a face to full height. Reaching a click is the activation the audio
    // needs. A clip that had already run out restarts from the top.
    //
    // The growth is INLINE, not an overlay: the chosen row itself expands and
    // pushes the rows below it down, an accordion rather than a card lifting
    // over its neighbours. The box (which holds the picture) grows to match and
    // stays welded to that row, top-anchored, so the two open as one.
    const focusedRow = () => stage.parentElement?.querySelector<HTMLElement>(".is-focused");

    const collapse = () => {
      stage.classList.remove("is-live");
      focusedRow()?.classList.remove("is-expanded");
    };

    // The click on the chosen presence is a TOGGLE. First press commits: it
    // plays, with sound, and a face opens to full height. Press it again and it
    // pauses and goes back the way it came — because the row is the only control
    // and pressing it twice should undo, not do nothing.
    const commit = () => {
      const m = media();
      if (!m || !src) return;

      if (stage.classList.contains("is-live")) {
        m.pause();
        collapse();
        return;
      }

      // Resume where it paused, unless it had run to the end. The click is the
      // activation, so this play() may carry sound without being refused.
      if (m.ended) m.currentTime = 0;
      m.play().catch(() => {});
      stage.classList.add("is-live");
      if (mode === "face") focusedRow()?.classList.add("is-expanded");
    };

    const silence = () => {
      stopMedia();
      collapse();
      stage.classList.remove("is-playing");
      stage.style.setProperty("--played", "0%");
      setKind("empty");
      src = "";
    };

    // A READIED FACE IS ITS FIRST FRAME, not a black rectangle — otherwise the
    // paused box gives no sign there is anyone in it. preload="metadata" paints
    // nothing on its own, so nudge the time a hair: a seek forces the browser to
    // decode and show that one frame while the video stays paused. Only when it
    // is genuinely at rest, so it never fights a clip that is playing.
    video?.addEventListener("loadedmetadata", () => {
      if (video.paused && video.currentTime === 0) {
        try {
          video.currentTime = 0.05;
        } catch {
          /* a source that refuses the seek stays black; not fatal */
        }
      }
    });

    // THE PROGRESS follows the media's OWN clock, on a rAF rather than the
    // 'timeupdate' event, which fires about four times a second and would make a
    // short clip's bar visibly step. It writes the played fraction to --played,
    // which is the width of the black layer.
    let raf = 0;
    const follow = () => {
      const m = media();
      if (m && m.duration) {
        stage.style.setProperty("--played", `${(m.currentTime / m.duration) * 100}%`);
      }
      raf = requestAnimationFrame(follow);
    };
    const track = () => {
      cancelAnimationFrame(raf);
      raf = requestAnimationFrame(follow);
    };

    // THE PLAY EFFECT AND THE REVERT both follow the media's OWN state rather
    // than our intentions, so a clip that ends or is paused by the browser tells
    // the truth. is-playing marks that something is running; ending drops the
    // commit so the box shrinks with nothing else asked of it.
    // is-playing rides both the stage AND the chosen row, so its kind mark can
    // pulse in the list while it plays — the same "playing now" the progress bar
    // and the moving picture already say, said once more where the eye is.
    for (const m of [video, audio]) {
      m?.addEventListener("play", () => {
        stage.classList.add("is-playing");
        focusedRow()?.classList.add("is-playing");
        track();
      });
      m?.addEventListener("pause", () => {
        stage.classList.remove("is-playing");
        focusedRow()?.classList.remove("is-playing");
        cancelAnimationFrame(raf);
      });
      m?.addEventListener("ended", () => {
        stage.classList.remove("is-playing");
        focusedRow()?.classList.remove("is-playing");
        cancelAnimationFrame(raf);
        stage.style.setProperty("--played", "0%");
        collapse();
      });
    }

    let settleTimer: number | undefined;
    // A snap scrolls, which settles, which may snap again. Bounded, so a snap
    // the scroller cannot perform (already at an end) gives up rather than loop.
    let snaps = 0;

    const rowHeight = () => items[0].getBoundingClientRect().height;

    // THE BAND SITS A FIXED ROW-AND-A-HALF FROM THE TOP, not a third of the way
    // down. The chosen presence reads NEAR THE TOP with a single row peeking
    // above it, rather than adrift near the middle of the panel — a fixed offset
    // rather than a fraction, so it does not drift lower as the panel grows
    // taller. It is measured off the row's real height, which is also why the
    // matching stage in the markup is pinned to the same 7.5rem.
    const bandFromTop = () => rowHeight() * 1.5;
    const bandCentre = () => scroll.getBoundingClientRect().top + bandFromTop();

    // Lead and trail are MEASURED, not written in the markup. A full row deeper
    // than the band, so the first row rests a row and a half below it and the
    // list opens unselected and silent.
    const pad = () => {
      const ul = scroll.querySelector<HTMLElement>("ul");
      if (!ul) return;
      const rh = rowHeight();
      ul.style.paddingTop = `${Math.max(0, bandFromTop() + rh)}px`;
      ul.style.paddingBottom = `${Math.max(0, scroll.clientHeight - bandFromTop() - rh / 2)}px`;
    };

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

    const clear = () =>
      items.forEach((i) => i.classList.remove("is-focused", "is-expanded", "is-playing"));

    const settle = () => {
      pad();
      scroll.classList.remove("is-scrolling");
      stage.classList.remove("is-scrolling");
      clear();
      const near = nearest();

      if (!near || Math.abs(near.delta) > rowHeight()) {
        scroll.classList.remove("has-selection");
        silence();
        snaps = 0;
        return;
      }

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
      preview(el);
    };

    scroll.addEventListener(
      "scroll",
      () => {
        // Moving: no selection, no sound, no placeholder — a row is passing
        // through the band and they would collide. The box reverts with it.
        scroll.classList.add("is-scrolling");
        stage.classList.add("is-scrolling");
        scroll.classList.remove("has-selection");
        clear();
        silence();
        window.clearTimeout(settleTimer);
        settleTimer = window.setTimeout(settle, 140);
      },
      { passive: true },
    );

    // Clicking a row that is NOT yet chosen scrolls it into the band — the same
    // act as scrolling it there by hand, and the gesture the audio will need.
    // Clicking the one already chosen is the commit: sound on, face enlarged.
    items.forEach((el) =>
      el.addEventListener("click", () => {
        if (el.classList.contains("is-focused")) {
          commit();
          return;
        }
        const r = el.getBoundingClientRect();
        scroll.scrollBy({ top: r.top + r.height / 2 - bandCentre(), behavior: "smooth" });
      }),
    );

    window.addEventListener("resize", settle);

    // Opening another relationship replaces this element; stop the progress loop
    // with it, or it runs on forever against a detached box.
    this.cleanup = () => cancelAnimationFrame(raf);

    requestAnimationFrame(() =>
      requestAnimationFrame(() => {
        pad();
        settle();
      }),
    );
  },

  destroyed(this: HookCtx) {
    this.cleanup?.();
  },
};
