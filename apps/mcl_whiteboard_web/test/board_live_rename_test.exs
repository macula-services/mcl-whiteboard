defmodule MclWhiteboardWeb.BoardLiveRenameTest do
  use ExUnit.Case, async: true

  alias MclWhiteboardWeb.BoardLive

  test "an accepted rename shows the new title and closes the editor" do
    assert BoardLive.rename_outcome({:ok, 3, []}, "Retro") ==
             [board_title: "Retro", editing_title?: false, rename_error: nil]
  end

  # The aggregate is the authority on the title. Showing the new one after
  # it refused would be a rename that silently never happened.
  test "a refused rename keeps the old title and says why, with the editor still open" do
    assigns = BoardLive.rename_outcome({:error, :archived}, "Retro")

    refute Keyword.has_key?(assigns, :board_title)
    assert assigns[:editing_title?] == true
    assert assigns[:rename_error] =~ "archived"
  end
end
