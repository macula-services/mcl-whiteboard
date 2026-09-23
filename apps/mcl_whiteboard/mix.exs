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
      {:mcl_om, "~> 0.26 and >= 0.26.5"},
      # The departments start BEFORE this app (they are its runtime deps),
      # so mcl_om:boot/1 finds their event handlers registered when it opens
      # the store, and Service.start/1 can declare subscriptions whose
      # handlers are already running. Same order as mcl-tube.
      {:guide_board_lifecycle, in_umbrella: true},
      {:project_boards, in_umbrella: true},
      {:query_boards, in_umbrella: true},
      {:track_presence, in_umbrella: true}
    ]
  end
end
