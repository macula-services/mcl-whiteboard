defmodule TrackPresence.PeerDepartedMeshSubscriber do
  # Same topic GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh
  # publishes to -- lets a graceful leave_board clear a departed peer's
  # cursor on every OTHER node immediately, instead of every node's own
  # Sweep having to wait out stale_after_ms independently. An ungraceful
  # disconnect never reaches this (no peer_departed_v1 gets emitted for
  # one, by design) and still relies on Sweep, same as always.
  @behaviour :macula_subscriber

  alias TrackPresence.Roster

  def topic, do: GuideBoardLifecycle.LeaveBoard.PeerDepartedV1ToMesh.topic()

  @impl true
  def init(_args), do: {:ok, nil}

  # Only this topic is ever routed here (one subscription per topic).
  @impl true
  def handle_event(topic, payload, _meta, state) when is_map(payload) do
    if topic == topic(), do: absorb(normalize(payload))
    {:noreply, state}
  end

  def handle_event(_topic, _payload, _meta, state), do: {:noreply, state}

  defp absorb(fact) do
    Roster.remove(field(:board_id, fact), field(:peer_id, fact))
  end

  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp normalize({:text, b}) when is_binary(b), do: b
  defp normalize(:undefined), do: nil
  defp normalize(m) when is_map(m), do: Map.new(m, fn {k, v} -> {normalize(k), normalize(v)} end)
  defp normalize(l) when is_list(l), do: Enum.map(l, &normalize/1)
  defp normalize(v), do: v
end
