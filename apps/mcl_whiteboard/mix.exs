defmodule MclWhiteboard.MixProject do
  use Mix.Project

  def project do
    [
      app: :mcl_whiteboard,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {MclWhiteboard.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # 1.4 is the macula-16 line on wire 1.0, the fleet's since the flag day
      # (2026-10-19). The major moves with the wire so no ~> 0.x service
      # floats onto a new wire by itself (mcl-om#27); a 1.0 node neither reads
      # a 14 node's frames nor handshakes with it, so this is taken on
      # purpose.
      {:mcl_om, "~> 1.4"},
      # THIS SERVICE'S OWN EVENT STORE. mcl_om opens no store and starts no
      # reckon-db or evoq application since 0.35.0 (mcl-om#10):
      # MclWhiteboard.Application opens the store in start/2 before
      # mcl_om:boot/1. Leaving these out compiles clean and boots with no
      # store at all.
      {:reckon_db, "~> 5.11"},
      {:evoq, "~> 1.24"},
      {:reckon_evoq, "~> 2.8"},
      # The departments start BEFORE this app (they are its runtime deps),
      # so their event handlers are registered when the store subscription
      # starts in start/2, and Service.start/1 can declare subscriptions
      # whose handlers are already running. Same order as mcl-tube.
      {:guide_board_lifecycle, in_umbrella: true},
      {:project_boards, in_umbrella: true},
      {:query_boards, in_umbrella: true},
      {:track_presence, in_umbrella: true},
      # The start-up ordering test replaces :mcl_om.boot/1 and the service's
      # event_store/0 for one call, so it can prove the store is open when
      # boot runs. Everything else passes through.
      {:meck, "~> 1.2", only: :test}
    ]
  end
end
