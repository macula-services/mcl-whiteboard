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
      # Wire 1.0 on macula 16 (macula-codebase-checks#4): the major moves with the
      # wire, so this is taken on purpose, with the facade that declares it. The
      # floor names 1.4 because `~> 1.0` also admits 1.3.0, which requires macula
      # `~> 15.6` (macula-codebase-checks#14).
      {:mcl_om, "~> 1.4"},
      {:macula, "~> 16.0"}
    ]
  end
end
