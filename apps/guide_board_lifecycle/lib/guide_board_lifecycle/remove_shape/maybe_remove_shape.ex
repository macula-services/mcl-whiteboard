defmodule GuideBoardLifecycle.RemoveShape.MaybeRemoveShape do
  # Handler for remove_shape_v1 -- mirrors MaybePlaceSticky's shape.
  alias GuideBoardLifecycle.BoardAggregate
  alias GuideBoardLifecycle.RemoveShape.RemoveShapeV1
  alias GuideBoardLifecycle.RemoveShape.ShapeRemovedV1
  alias GuideBoardLifecycle.ShapeMutation.AnswerShapeMutationRequests

  require Logger

  def handle_from_map(payload) do
    case RemoveShapeV1.from_map(payload) do
      {:ok, cmd} -> handle(cmd)
      {:error, _} = error -> error
    end
  end

  def handle(%RemoveShapeV1{} = cmd) do
    event = ShapeRemovedV1.from_command(cmd)
    {:ok, [ShapeRemovedV1.to_map(event)]}
  end

  def dispatch(%{board_id: board_id} = params) do
    case RemoveShapeV1.new(params) do
      {:ok, cmd} ->
        evoq_cmd =
          :evoq_command.new(
            :remove_shape,
            BoardAggregate,
            BoardAggregate.stream_id(board_id),
            RemoveShapeV1.to_map(cmd)
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
      Map.put(params, :command_type, "remove_shape"),
      %{mode: :async_log}
    )
  end
end
