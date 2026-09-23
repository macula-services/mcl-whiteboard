defmodule GuideBoardLifecycle.PlaceSticky.MaybePlaceSticky do
  # Handler for place_sticky_v1 -- mirrors MaybeDrawStroke's shape,
  # including the same write-relay split (dispatch locally if this node
  # hosts the board, relay over mesh to the real host otherwise). Unlike
  # draw_stroke, sticky/text/move/remove share ONE relay-request topic
  # (see AnswerShapeMutationRequests) instead of one topic each -- they're
  # siblings of the same "shape mutation" concern, not separate features,
  # so the plumbing is shared while each stays its own CMD desk.
  alias GuideBoardLifecycle.BoardAggregate
  alias GuideBoardLifecycle.PlaceSticky.PlaceStickyV1
  alias GuideBoardLifecycle.ShapeLifecycle.ShapeInitiatedV1
  alias GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests

  require Logger

  def handle_from_map(payload) do
    case PlaceStickyV1.from_map(payload) do
      {:ok, cmd} -> handle(cmd)
      {:error, _} = error -> error
    end
  end

  def handle(%PlaceStickyV1{} = cmd) do
    event =
      ShapeInitiatedV1.new(%{
        board_id: PlaceStickyV1.board_id(cmd),
        shape_id: PlaceStickyV1.shape_id(cmd),
        kind: "sticky",
        points: [%{x: PlaceStickyV1.x(cmd), y: PlaceStickyV1.y(cmd)}],
        color: PlaceStickyV1.color(cmd),
        text: PlaceStickyV1.text(cmd)
      })

    {:ok, [ShapeInitiatedV1.to_map(event)]}
  end

  def dispatch(%{board_id: board_id} = params) do
    case PlaceStickyV1.new(params) do
      {:ok, cmd} ->
        evoq_cmd =
          :evoq_command.new(
            :place_sticky,
            BoardAggregate,
            BoardAggregate.stream_id(board_id),
            PlaceStickyV1.to_map(cmd)
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
      Map.put(params, :command_type, "place_sticky"),
      %{mode: :async_log}
    )
  end
end
