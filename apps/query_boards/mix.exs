defmodule QueryBoards.MixProject do
  use Mix.Project

  def project do
    [
      app: :query_boards,
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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Reads the same ETS tables project_boards owns -- only umbrella dep
      # needed for that half is the table-name atoms, not for calling any
      # of its code.
      {:project_boards, in_umbrella: true},
      # For AnswerBoardSnapshotQueries: BoardStatus's hosted/archived bit
      # flags -- the CMD app owns what the status bits mean, this just
      # reads them, same direction mcl_whiteboard_web already depends
      # on guide_board_lifecycle for the identical reason.
      {:guide_board_lifecycle, in_umbrella: true},
      # For the mesh queries: :mcl_om.mesh_handles/0 for the per-call reply
      # subscription, :mcl_om_pubsub for every publish.
      {:mcl_om, "~> 0.26 and >= 0.26.5"},
      {:macula, "~> 12.1"}
    ]
  end
end
