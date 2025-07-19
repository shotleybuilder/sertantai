defmodule SertantaiDocsWeb.DocHTML do
  @moduledoc """
  This module contains pages rendered by DocController.
  """
  use SertantaiDocsWeb, :html

  embed_templates "doc_html/*"
end