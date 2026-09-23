defmodule GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh do
  # Republishes every locally-recorded peer_departed_v1 as a mesh fact, so
  # every peer viewing this board (not just this host's own local viewers)
  # can drop that cursor immediately rather than waiting out
  # TrackPresence's own ~20s sweep timeout. Mirrors StrokeDrawnV1ToMesh's
  # shape exactly, including the same catchup-replay-republishes-on-restart
  # gap -- harmless here by construction, unlike strokes: a peer_id is
  # fresh per LiveView mount (see BoardLive), so a replayed departure can
  # never collide with a peer who reconnected since, it can only ever
  # remove an already-gone (or never-present) roster entry. No dedup
  # needed.
  @behaviour :evoq_event_handler

  alias GuideBoardLifecycle.WhiteboardTopic

  def topic, do: WhiteboardTopic.build("presence", "peer_departed")

  @impl true
  def interested_in, do: ["peer_departed_v1"]

  # A departure is only news while the peer's cursor is still on screen; a
  # replayed one after a restart would be harmless (see above) but is noise.
  @impl true
  def replay_policy, do: :skip

  @impl true
  def init(_config), do: {:ok, %{}}

  @impl true
  def handle_event("peer_departed_v1", event, _metadata, state) do
    data = field(:data, event)

    fact = %{
      board_id: field(:board_id, data),
      peer_id: field(:peer_id, data),
      departed_at: field(:departed_at, data)
    }

    publish(fact)
    {:ok, state}
  end

  # A refused publish is logged by mcl_om (async_log).
  defp publish(fact) do
    _ = :mcl_om_pubsub.publish(topic(), fact, %{mode: :async_log})
    :ok
  end

  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end
end
