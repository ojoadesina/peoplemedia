defmodule PeoplemediaWeb.UiLive do
  @moduledoc """
  An empty page at `/ui`, held open.

  The route is the only thing being kept. What was here is in the history if any
  of it is ever wanted back.
  """
  use PeoplemediaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "UI")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="app-root fixed inset-0 z-0 overflow-y-auto bg-light-50 font-mono dark:bg-dark-950">
    </div>
    """
  end
end
