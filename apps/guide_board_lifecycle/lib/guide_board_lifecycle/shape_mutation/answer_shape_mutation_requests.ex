defmodule GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests do
  # Write-relay for a joining (non-hosting) peer's shape mutations --
  # place_sticky, place_text, move_shape, remove_shape, draw_geometry.
  # One shared topic for all five (mirrors AnswerDrawStrokeRequests'
  # per-topic design, but consolidated: these are siblings of one "shape
  # mutation" concern, not separate features like draw_stroke vs
  # rename_board, so sharing the relay plumbing avoids five
  # near-identical subscriber/starter pairs). Every node subscribes; the
  # embedded command_type field picks which desk's dispatch/1 handles
  # it, and that desk's own BoardAggregate guard (:not_hosted) makes
  # every node except the real host a safe no-op -- exactly the
  # authority-check-for-free trick draw_stroke's write-relay already
  # uses.
  @behaviour :macula_subscriber

  alias GuideBoardLifecycle.DrawGeometry.MaybeDrawGeometry
  alias GuideBoardLifecycle.MoveShape.MaybeMoveShape
  alias GuideBoardLifecycle.PlaceSticky.MaybePlaceSticky
  alias GuideBoardLifecycle.PlaceText.MaybePlaceText
  alias GuideBoardLifecycle.RemoveShape.MaybeRemoveShape

  require Logger

  alias GuideBoardLifecycle.WhiteboardTopic

  def topic, do: WhiteboardTopic.build("shape", "shape_mutation_request")

  @impl true
  def init(_args), do: {:ok, nil}

  # Only this topic is ever routed here (one subscription per topic); the
  # check keeps a misrouted event from being dispatched as a command.
  @impl true
  def handle_event(topic, payload, _meta, state) do
    if topic == topic(), do: answer(payload)
    {:noreply, state}
  end

  defp answer(payload) do
    fact = normalize(payload)
    command_type = field(:command_type, fact)
    board_id = field(:board_id, fact)

    command_type
    |> dispatch(board_id, fact)
    |> report(command_type, board_id)
  end

  # One clause per command_type: the desk it names, with the fields that
  # desk's command takes.
  defp dispatch("place_sticky", board_id, fact),
    do:
      MaybePlaceSticky.dispatch(Map.put(take(fact, [:x, :y, :color, :text]), :board_id, board_id))

  defp dispatch("place_text", board_id, fact),
    do: MaybePlaceText.dispatch(Map.put(take(fact, [:x, :y, :color, :text]), :board_id, board_id))

  defp dispatch("move_shape", board_id, fact),
    do: MaybeMoveShape.dispatch(Map.put(take(fact, [:shape_id, :points]), :board_id, board_id))

  defp dispatch("remove_shape", board_id, fact),
    do: MaybeRemoveShape.dispatch(Map.put(take(fact, [:shape_id]), :board_id, board_id))

  defp dispatch("draw_geometry", board_id, fact) do
    fact
    |> take([:kind, :points, :color, :from_shape_id, :to_shape_id])
    |> Map.put(:board_id, board_id)
    |> MaybeDrawGeometry.dispatch()
  end

  defp dispatch(other, _board_id, _fact), do: {:error, {:unknown_command_type, other}}

  defp report({:ok, _version, _events}, command_type, board_id),
    do: Logger.info("[AnswerShapeMutationRequests] handled #{command_type} for #{board_id}")

  # Every node except the real host gets this; expected, not worth a line.
  defp report({:error, :not_hosted}, _command_type, _board_id), do: :ok

  defp report({:error, reason}, _command_type, _board_id),
    do: Logger.warning("[AnswerShapeMutationRequests] dispatch failed: #{inspect(reason)}")

  defp take(fact, keys), do: Map.new(keys, &{&1, field(&1, fact)})

  defp field(key, map) when is_atom(key) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp normalize({:text, b}) when is_binary(b), do: b
  defp normalize(:undefined), do: nil
  defp normalize(m) when is_map(m), do: Map.new(m, fn {k, v} -> {normalize(k), normalize(v)} end)
  defp normalize(l) when is_list(l), do: Enum.map(l, &normalize/1)
  defp normalize(v), do: v
end
