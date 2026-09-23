defmodule QueryBoards.OneShotMeshReply do
  # :macula_subscriber callback for the single expected reply to ONE request
  # -- forwards the reply carrying its own request_id to the owner pid that
  # started it, then stops itself. Used by GetBoardSnapshotByIdOverMesh.
  #
  # The reply topic is fixed (IDs in the payload, never in the topic), so
  # every asker on this node hears every reply to every snapshot query; the
  # request_id is how each picks out its own, and anyone else's is ignored.
  #
  # The gen_server this wraps stays linked to whichever process called
  # :macula_subscriber.start_link/5 -- a normal {:stop, :normal, _} exit
  # here does not propagate to that linked caller, so the caller is free to
  # `receive` for the forwarded message and, on timeout, explicitly stop
  # this pid itself to avoid leaking a dangling subscription.
  @behaviour :macula_subscriber

  alias QueryBoards.MeshReplyId

  @impl true
  def init({owner, request_id}) when is_pid(owner) and is_binary(request_id),
    do: {:ok, {owner, request_id}}

  @impl true
  def handle_event(_topic, payload, _meta, {owner, request_id} = state) do
    if MeshReplyId.answers?(payload, request_id) do
      send(owner, {:one_shot_mesh_reply, payload})
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end
end
