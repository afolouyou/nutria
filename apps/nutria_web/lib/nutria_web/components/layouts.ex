defmodule NutriaWeb.Layouts do
  @moduledoc """
  Phoenix layouts module.
  """
  use NutriaWeb, :html

  import NutriaWeb.CoreComponents

  embed_templates "layouts/*"
end
