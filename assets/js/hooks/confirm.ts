// THE IRREVERSIBLE-PRESS LAW, ported from the project this app grew out of.
//
// A press that cannot be taken back never fires on the first tap. The first
// ARMS it and puts a question on screen; a second tap on the SAME control,
// within the window, runs it. Anything else — a different control, a scroll,
// the window closing, or simply waiting — disarms it.
//
// WHY IT IS NEEDED HERE and not on every button: unscoping sits behind a
// horizontal swipe on a vertically scrolling list, which is the one gesture a
// thumb makes by accident. Everything else uncovered by that swipe opens a room
// and asks something; this one would act, immediately, on a tie that took two
// people three rounds to agree.
//
// IT LIVES IN THE BROWSER because it is entirely about a gesture. The server
// never hears the first press, so there is no half-armed state on it to get out
// of step with — and a reload disarms by construction.
// IT ALSO CARRIES RECEIPTS NOW, and the two kinds of line share the box and
// nothing else. A confirmation is a QUESTION — it arms a press and waits for the
// second; a receipt is the answer to one already given, and there is nothing on
// it to confirm. Sending a letter is the app's one act with no room to report
// into: the room it was written in has closed by the time it lands.
type ConfirmCtx = {
  el: HTMLElement;
  handleEvent: (event: string, cb: (payload: { words: string }) => void) => unknown;
  removeHandleEvent: (ref: unknown) => void;
  cleanup?: () => void;
};

const WINDOW_MS = 6000;

export const Confirm = {
  // IT LIVES ON THE TOAST, not on the list, because the toast is the thing it
  // owns — and because the list already carries a hook and an element may only
  // have one. The presses it cares about are listened for on the document, in
  // the capture phase, which is what lets it stop one before LiveView sees it.
  mounted(this: ConfirmCtx) {
    const toast = this.el;
    const line = toast.querySelector<HTMLElement>(".toast-line");

    let armed: string | null = null;
    let timer: number | undefined;

    const hide = () => {
      armed = null;
      window.clearTimeout(timer);
      toast.hidden = true;
    };

    const say = (words: string) => {
      if (line) line.textContent = words;
      toast.hidden = false;
      window.clearTimeout(timer);
      timer = window.setTimeout(hide, WINDOW_MS);
    };

    // ARMING IS SAYING PLUS REMEMBERING WHAT WAS ASKED. Split out so a receipt
    // can borrow the showing without borrowing the question — a toast that
    // armed nothing but left `armed` set would make the next press anywhere
    // read as a confirmation of something that already happened.
    const ask = (key: string, words: string) => {
      armed = key;
      say(words);
    };

    // THE SERVER'S OWN LINE. It arrives after the patch that carried the act,
    // so the room has already closed and the list has already re-read — which
    // is why this is a receipt rather than a status.
    const said = this.handleEvent("toast", ({ words }) => say(words));

    // Capture, so the decision is made BEFORE the click reaches LiveView's own
    // handler — stopping it there is the whole mechanism.
    const onClick = (e: MouseEvent) => {
      const el = (e.target as HTMLElement).closest?.("[data-unscope]") as HTMLElement | null;

      if (!el) {
        // A press anywhere else is a change of mind, not a confirmation.
        if (armed) hide();
        return;
      }

      const key = el.dataset.unscope || "";
      if (armed === key) {
        hide();
        return; // let it through — this is the second press
      }

      e.preventDefault();
      e.stopPropagation();
      // Their name, so the question is about somebody rather than about a
      // button. It is on the row this control belongs to.
      const who = el
        .closest(".scopes-item")
        ?.querySelector(".scopes-line")
        ?.textContent?.trim()
        .split(/\s{2,}|\n/)[0];
      ask(key, who ? `TAP AGAIN TO UNSCOPE ${who}` : "TAP AGAIN TO UNSCOPE");
    };

    // A moving list disarms: whatever you were about to confirm is no longer
    // under your thumb.
    //
    // THE `armed &&` IS LOAD-BEARING NOW RATHER THAN MERELY TIDY. This listens
    // in the capture phase, so it hears every scroller on the page — including
    // the horizontal one inside each row, which the send resets in the same
    // tick the receipt appears. Without the guard the toast would dismiss
    // itself before it was read.
    const onScroll = () => armed && hide();

    document.addEventListener("click", onClick, true);
    document.addEventListener("scroll", onScroll, true);

    this.cleanup = () => {
      window.clearTimeout(timer);
      this.removeHandleEvent(said);
      document.removeEventListener("click", onClick, true);
      document.removeEventListener("scroll", onScroll, true);
    };
  },

  destroyed(this: ConfirmCtx) {
    this.cleanup?.();
  },
};
