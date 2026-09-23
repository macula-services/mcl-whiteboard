defmodule GuideBoardLifecycle.ShapeLifecycle.ShapeLifecycleV1ToMesh do
  # Republishes every LOCALLY-originated shape_initiated_v1/
  # shape_amended_v1/shape_removed_v1 as a mesh fact -- the CMD-side half
  # of shape replication (ProjectBoards.ShapeLifecycleMeshSubscriber is
  # the other half, same three topic strings, must match). Replaces
  # StrokeDrawnV1ToMesh (its own dedicated topic) and ShapeMutatedV1ToMesh
  # (one shared topic for sticky/text/move/remove/geometry) -- now that
  # shape creation is ONE event type instead of four, the same
  # shared-vs-separate-topic question BoardLifecycleV1ToMesh already
  # settled applies here too.
  #
  # One topic PER event type, not one shared topic: "a shape was
  # created", "an existing shape changed", and "a shape was removed" are
  # three distinct kinds of news, not variations of one action -- a
  # future consumer that only cares about removals shouldn't have to
  # filter the other two out. This is a DIFFERENT call than
  # ShapeMutatedV1ToMesh's old shared topic, on purpose: that shared
  # topic was for five events that were all genuine siblings of one
  # concern ("what's drawn on this board changed"); initiated/amended/
  # removed are lifecycle STAGES, not siblings, same distinction that
  # decided BoardLifecycleV1ToMesh's own design.
  @behaviour :evoq_event_handler

  alias GuideBoardLifecycle.WhiteboardTopic

  @event_types ~w(shape_initiated_v1 shape_amended_v1 shape_removed_v1)

  def topic(event_type) when event_type in @event_types,
    do: WhiteboardTopic.build("shape", String.replace_suffix(event_type, "_v1", ""))

  def topics, do: Enum.map(@event_types, &topic/1)

  @impl true
  def interested_in, do: @event_types

  # Peers that were listening already drew these shapes; peers that were
  # not get them from a snapshot query, never from a replayed republish.
  @impl true
  def replay_policy, do: :skip

  @impl true
  def init(_config), do: {:ok, %{}}

  @impl true
  def handle_event(event_type, event, _metadata, state) do
    data = field(:data, event)

    fact = %{
      board_id: field(:board_id, data),
      shape_id: field(:shape_id, data),
      kind: field(:kind, data),
      points: field(:points, data),
      color: field(:color, data),
      width: field(:width, data),
      text: field(:text, data),
      from_shape_id: field(:from_shape_id, data),
      to_shape_id: field(:to_shape_id, data)
    }

    publish(event_type, fact)
    {:ok, state}
  end

  # A refused publish is logged by mcl_om (async_log).
  defp publish(event_type, fact) do
    _ = :mcl_om_pubsub.publish(topic(event_type), fact, %{mode: :async_log})
    :ok
  end

  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end
end
