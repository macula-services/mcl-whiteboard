defmodule GuideBoardLifecycle.MixProject do
  use Mix.Project

  def project do
    [
      app: :guide_board_lifecycle,
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
      mod: {GuideBoardLifecycle.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:evoq, "~> 1.24 and >= 1.24.1"},
      # Declared directly (not just pulled in transitively via mcl_om) --
      # this app mints stream ids straight from its own command constructors,
      # mirroring mcl-tube's guide_tube_lifecycle.
      {:reckon_gater, "~> 3.11"},
      # The mesh emitters publish through :mcl_om_pubsub; macula for
      # :macula_topic (WhiteboardTopic) and the :macula_subscriber behaviour.
      {:mcl_om, "~> 0.28 and >= 0.28.1"},
      {:macula, "~> 12.2"}
    ]
  end
end
