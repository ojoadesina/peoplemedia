defmodule PeoplemediaWeb.RecorderLive do
  @moduledoc """
  A REFERENCE EXHIBIT, not a feature.

  This is the recorder UI from the earlier app, reproduced as markup so it can be
  looked at and argued with. There is deliberately no hook, no getUserMedia and
  no MediaRecorder — nothing here records anything. The original `phx-hook` is
  omitted on purpose so LiveView does not go looking for a hook that is not
  there.

  What IS faithful is the structure, because the structure is the invention. The
  behaviour notes on the page are read out of the original hook rather than
  guessed at, and the layer boxes are annotated so the mechanism is visible
  standing still — which a scroll-snap interface otherwise never is.

  ## The idea, as the original JS describes it

  Three scroll-snap layers stacked on one another, each 95% wide so the next one
  always peeks. Swiping is not navigation here — it is the TRANSPORT. Swipe
  distance past a threshold is what starts, pauses and switches the stream, so
  the same gesture that reveals a layer is the gesture that arms it.

  Delete this module the moment it has been mined for whatever it is worth.
  """
  use PeoplemediaWeb, :live_view

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-light-50 px-8 py-10 font-mono dark:bg-dark-950">
      <div class="mx-auto max-w-3xl">
        <p class="text-sm tracking-[0.18em] text-light-600 dark:text-dark-400">
          REFERENCE — THE OLD RECORDER
        </p>
        <p class="mt-2 max-w-xl text-sm leading-6 text-light-500 dark:text-dark-500">
          Markup only. Nothing records. Drag the panel sideways — it is a scroll
          container, and the swipe itself was the transport.
        </p>

        <%!-- ── THE EXHIBIT ────────────────────────────────────────────────────
             Reproduced as written, including two class names that never
             resolved in the original either: `bg-backrgound-100` and `text-sml`
             are both typos, so those two elements were always unstyled. Left in
             rather than quietly fixed, because the point is to see what was
             actually running. --%>
        <div class="mt-10 w-full max-w-md">
          <div id="recorder-slot" class="smalltalk-slot relative h-54 shrink-0">
            <div id="recorder-entry" class="absolute inset-0 w-full overflow-hidden">
              <div class="relative h-full w-full bg-black">
                <video
                  id="recorder-video-preview"
                  class="absolute inset-0 hidden h-full w-full object-cover"
                  autoplay
                  muted
                  playsinline
                >
                </video>

                <div class="absolute bottom-4 left-8 flex flex-col space-y-4">
                  <p class="recorder-status text-sm text-sky-400">recording audio...</p>
                  <span class="recorder-time text-sm text-gray-400">0:07</span>
                </div>
              </div>
            </div>

            <div
              id="recorder-layer"
              class="no-scrollbar relative flex h-full snap-x snap-mandatory overflow-x-auto"
            >
              <div
                id="recorder-layer-swipe"
                class="relative h-full w-full shrink-0 snap-start bg-primary-100 transition-colors duration-200"
              >
                <div class="absolute -top-4 right-4">
                  <.icon
                    name="hero-microphone-solid"
                    class="h-12 w-12 rotate-[180deg] text-primary-200/70"
                  />
                </div>

                <div class="relative flex h-full w-full flex-col space-y-4 px-4 py-4">
                  <div class="flex items-start justify-between">
                    <div class="text-primary-500">
                      <button
                        id="recorder-stream-smalltalk"
                        type="button"
                        class="transition hover:text-red-500"
                      >
                        <.icon name="hero-plus" class="h-5 w-5" />
                      </button>
                    </div>

                    <div class="text-right">
                      <div class="flex items-center justify-end gap-1">
                        <span class="text-sml text-primary-500">you,</span>
                        <span class="text-sml text-gray-400">now</span>
                      </div>
                      <span class="recorder-time text-sm text-gray-400">0:07</span>
                    </div>
                  </div>

                  <div class="flex-1"></div>

                  <div class="">
                    <p class="recorder-status text-sm text-sky-400">
                      <span class="text-lg text-neutral-300">→</span>
                    </p>
                  </div>

                  <textarea
                    id="recorder-text"
                    placeholder="small write......."
                    class="w-full resize-none border-0 bg-transparent text-sm text-primary-600 placeholder:text-primary-300 focus:ring-0 focus:outline-none"
                    rows="2"
                  ></textarea>
                </div>
              </div>

              <div id="audio-trigger" class="w-[95%] shrink-0 snap-end">
                <div
                  id="layer-inner"
                  class="no-scrollbar relative flex h-full snap-x snap-mandatory overflow-x-auto"
                >
                  <div id="layer-inner-swipe" class="bg-backrgound-100 w-full shrink-0 snap-start">
                    <div class="h-full w-full bg-secondary-500/60">
                      <div class="absolute bottom-20 px-2">
                        <span class="text-lg text-neutral-300">→</span>
                      </div>
                    </div>
                  </div>
                  <div id="video-trigger" class="w-[95%] shrink-0 snap-end"></div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- ── WHAT IT DOES ───────────────────────────────────────────────────
             Read out of the original hook rather than remembered. A scroll-snap
             interface is invisible standing still, so the mechanism is written
             down beside it. --%>
        <div class="mt-14 max-w-xl space-y-8 text-sm leading-6">
          <div>
            <p class="tracking-[0.18em] text-light-600 dark:text-dark-400">THE STACK</p>
            <ul class="mt-3 space-y-2 text-light-500 dark:text-dark-500">
              <li>
                <span class="text-primary-600 dark:text-primary-500">entry</span>
                — underneath, always there. Black panel holding the camera preview,
                the status line and the clock. You only see it once something above
                it has been slid away.
              </li>
              <li>
                <span class="text-primary-600 dark:text-primary-500">layer</span>
                — the card on top: plus button, "you, now", the clock again, and the
                text field. This is what you drag.
              </li>
              <li>
                <span class="text-primary-600 dark:text-primary-500">layer-inner</span>
                — a second scroller nested inside the first one's trailing 95%, so
                the audio/video switch is a swipe WITHIN a swipe.
              </li>
            </ul>
          </div>

          <div>
            <p class="tracking-[0.18em] text-light-600 dark:text-dark-400">
              THE SWIPE IS THE TRANSPORT
            </p>
            <ul class="mt-3 space-y-2 text-light-500 dark:text-dark-500">
              <li>
                Outer, left past 80% of 95% width — start fresh audio, or resume what was paused.
              </li>
              <li>Outer, back right — pause. Not stop: the elapsed time is banked and carries on.</li>
              <li>Inner, left by hand — cancel everything and start fresh VIDEO.</li>
              <li>Inner, right by hand — cancel video, start fresh AUDIO.</li>
              <li>
                Resuming a paused video auto-swipes the inner layer for you, with a
                flag held for 500ms so the listener does not read the app's own
                scroll as a user's.
              </li>
              <li>
                Double-tap the layer — send. Refuses, and shakes, with nothing recorded and nothing written.
              </li>
            </ul>
          </div>

          <div>
            <p class="tracking-[0.18em] text-light-600 dark:text-dark-400">THE LIMITS IT CARRIED</p>
            <ul class="mt-3 space-y-2 text-light-500 dark:text-dark-500">
              <li>
                60 seconds, or 5MB, whichever arrives first — then it stops itself and holds the take.
              </li>
              <li>
                8 seconds of silence at the START and it cancels outright. Once it has
                heard anything at all, that timer never fires again.
              </li>
              <li>A take under 1 second is discarded rather than saved.</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
