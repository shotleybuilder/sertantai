defmodule SertantaiDocs.Docs do
  @moduledoc """
  Documentation domain for managing articles, navigation, and content.
  """

  use Ash.Domain

  resources do
    resource SertantaiDocs.Docs.Article
  end
end