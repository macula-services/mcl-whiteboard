defmodule GuideBoardLifecycle.WhiteboardTopic do
  # Every mesh topic this service publishes or subscribes to, built the one
  # canonical way: macula_topic:app_fact/6, five segments,
  # {realm}/{org}/whiteboard/{domain}/{name}_v{N}, IDs in the payload and
  # never in the topic (macula's TOPIC_NAMING_GUIDE).
  #
  # The builder lives here because this app produces most of the facts, and
  # the producer owns a fact's contract: consumers (project_boards,
  # track_presence, query_boards) call the producer's own topic/0 rather
  # than repeating the string, so the two halves of a pair cannot drift.
  #
  # The realm NAME and the org are read at call time, not compiled in. The
  # realm name comes from config/runtime.exs, which also derives the pool's
  # realm tag from it, so topics and pool always name the same realm. The org
  # is mcl_om's own `org`, the namespace the realm delegates to this node.
  @app "whiteboard"
  @version 1

  def build(domain, name) when is_binary(domain) and is_binary(name) do
    :macula_topic.app_fact(realm_name(), org(), @app, domain, name, @version)
  end

  @doc """
  Who may deliver to a subscription of this service: a node the realm has
  delegated this service's org (`{:org, org}`, mcl-whiteboard#15, T8).

  Every subscription here (the facts other hosts publish, the write requests
  a joined peer relays, the cursor facts and the query replies) comes from
  another node running this service. `members` would let any admitted
  service in the realm relay writes to a board here, and `open` would let any
  node. macula 18 refuses a subscription that names no source at all.
  """
  @spec sources() :: {:org, binary()}
  def sources, do: {:org, org()}

  defp realm_name, do: Application.fetch_env!(:mcl_whiteboard, :realm_name)
  defp org, do: Application.fetch_env!(:mcl_om, :org)
end
