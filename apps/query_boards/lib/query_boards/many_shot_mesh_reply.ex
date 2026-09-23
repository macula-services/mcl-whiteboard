defmodule QueryBoards.ManyShotMeshReply do
  # :macula_subscriber callback for collecting a REPLY FROM EVERY RESPONDER
  # to ONE request, not just the first (contrast QueryBoards.OneShotMeshReply,
  # used by join_board where exactly one authoritative host answers).
  # Forwards every reply carrying its own request_id to the owner pid and
  # keeps running -- the owner stops this subscriber once its collection
  # window closes (see ListBoardsOverMesh). Replies to anyone else's request
  # share the same fixed reply topic and are ignored.
  @behaviour :macula_subscriber

  alias QueryBoards.MeshReplyId

  @impl true
  def init({owner, request_id}) when is_pid(owner) and is_binary(request_id),
    do: {:ok, {owner, request_id}}

  @impl true
  def handle_event(_topic, payload, _meta, {owner, request_id} = state) do
    if MeshReplyId.answers?(payload, request_id), do: send(owner, {:mesh_reply, payload})
    {:noreply, state}
  end
end
