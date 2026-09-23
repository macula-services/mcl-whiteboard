defmodule TrackPresence.Supervisor do
  # Owns the roster's lifetime and the sweep timer. The two inbound mesh
  # subscribers are mcl_om's to supervise (MclWhiteboard.Service.
  # subscriptions/0). Mirrors ProjectBoards.Supervisor's shape (store first,
  # then everything that reads/writes it). Does NOT start
  # MclWhiteboardWeb.PubSub itself -- project_boards' own Supervisor
  # already does, and this app's mix.exs dependency on project_boards
  # guarantees it starts first (see that dep's own comment).
  @moduledoc false

  use Supervisor

  def start_link, do: Supervisor.start_link(__MODULE__, [], name: __MODULE__)

  @impl true
  def init([]) do
    children = [
      TrackPresence.Roster,
      TrackPresence.Sweep
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
