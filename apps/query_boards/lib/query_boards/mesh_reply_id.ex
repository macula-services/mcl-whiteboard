defmodule QueryBoards.MeshReplyId do
  # The request_id that ties a reply on a shared reply topic to the one
  # request that asked for it. Minted by the asker, echoed by every answerer.
  # A received key or value may arrive bare, as an atom, or as a {:text, _}
  # marker, depending on which atoms the receiving VM already knows, so all
  # three are accepted.

  def mint, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

  def answers?(payload, request_id) when is_map(payload) and is_binary(request_id),
    do: Enum.any?(payload, fn {k, v} -> text(k) == "request_id" and text(v) == request_id end)

  def answers?(_payload, _request_id), do: false

  defp text({:text, b}) when is_binary(b), do: b
  defp text(a) when is_atom(a), do: Atom.to_string(a)
  defp text(b), do: b
end
