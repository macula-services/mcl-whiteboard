defmodule GuideBoardLifecycle.PlaceText.MaybePlaceText do
  # Handler for place_text_v1 -- mirrors MaybePlaceSticky's shape exactly.
  alias GuideBoardLifecycle.BoardAggregate
  alias GuideBoardLifecycle.PlaceText.PlaceTextV1
  alias GuideBoardLifecycle.ShapeLifecycle.ShapeInitiatedV1
  alias GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests

  require Logger

  def handle_from_map(payload) do
    case PlaceTextV1.from_map(payload) do
      {:ok, cmd} -> handle(cmd)
      {:error, _} = error -> error
    end
  end

  def handle(%PlaceTextV1{} = cmd) do
    event =
      ShapeInitiatedV1.new(%{
        board_id: PlaceTextV1.board_id(cmd),
        shape_id: PlaceTextV1.shape_id(cmd),
        kind: "text",
        points: [%{x: PlaceTextV1.x(cmd), y: PlaceTextV1.y(cmd)}],
        color: PlaceTextV1.color(cmd),
        text: PlaceTextV1.text(cmd)
      })

    {:ok, [ShapeInitiatedV1.to_map(event)]}
  end

  def dispatch(%{board_id: board_id} = params) do
    case PlaceTextV1.new(params) do
      {:ok, cmd} ->
        evoq_cmd =
          :evoq_command.new(
            :place_text,
            BoardAggregate,
            BoardAggregate.stream_id(board_id),
            PlaceTextV1.to_map(cmd)
          )

        :evoq_router.dispatch(evoq_cmd)

      {:error, _} = error ->
        error
    end
  end

  # {:error, :mesh_unavailable} when this node has no mesh; a refused
  # publish is logged by mcl_om (async_log).
  def relay(%{board_id: _} = params) do
    :mcl_om_pubsub.publish(
      AnswerShapeMutationRequests.topic(),
      Map.put(params, :command_type, "place_text"),
      %{mode: :async_log}
    )
  end
end
