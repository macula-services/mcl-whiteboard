defmodule GuideBoardLifecycle.MoveShape.MaybeMoveShape do
  # Handler for move_shape_v1 -- mirrors MaybePlaceSticky's shape.
  alias GuideBoardLifecycle.BoardAggregate
  alias GuideBoardLifecycle.MoveShape.MoveShapeV1
  alias GuideBoardLifecycle.ShapeLifecycle.ShapeAmendedV1
  alias GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests

  require Logger

  def handle_from_map(payload) do
    case MoveShapeV1.from_map(payload) do
      {:ok, cmd} -> handle(cmd)
      {:error, _} = error -> error
    end
  end

  def handle(%MoveShapeV1{} = cmd) do
    event = ShapeAmendedV1.from_command(cmd)
    {:ok, [ShapeAmendedV1.to_map(event)]}
  end

  def dispatch(%{board_id: board_id} = params) do
    case MoveShapeV1.new(params) do
      {:ok, cmd} ->
        evoq_cmd =
          :evoq_command.new(
            :move_shape,
            BoardAggregate,
            BoardAggregate.stream_id(board_id),
            MoveShapeV1.to_map(cmd)
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
      Map.put(params, :command_type, "move_shape"),
      %{mode: :async_log}
    )
  end
end
