defmodule NutriaWeb.ErrorHTML do
  @moduledoc """
  Renders error pages for HTML format.
  """
  use NutriaWeb, :html

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
