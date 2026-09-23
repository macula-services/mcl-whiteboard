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

  defp realm_name, do: Application.fetch_env!(:mcl_whiteboard, :realm_name)
  defp org, do: Application.fetch_env!(:mcl_om, :org)
end
