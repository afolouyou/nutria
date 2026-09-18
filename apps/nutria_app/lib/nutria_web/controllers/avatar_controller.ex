defmodule NutriaWeb.Controllers.AvatarController do
  use NutriaWeb, :controller

  action_fallback(NutriaWeb.Controllers.FallbackController)

  def create(conn, %{"data" => data_url}) do
    user_id = conn.assigns.current_user_id
    user = Nutria.Accounts.get_user!(user_id)

    case Nutria.Uploads.store_data_url(data_url, user_id) do
      {:ok, filename} ->
        Nutria.Uploads.delete(user.avatar)
        {:ok, updated} = Nutria.Accounts.update_avatar(user, filename)
        json(conn, Nutria.Accounts.user_to_map(updated))

      {:error, _, detail} ->
        {:error, :bad_request, detail}
    end
  end

  def delete(conn, _params) do
    user_id = conn.assigns.current_user_id
    user = Nutria.Accounts.get_user!(user_id)
    Nutria.Uploads.delete(user.avatar)
    {:ok, updated} = Nutria.Accounts.clear_avatar(user)
    json(conn, Nutria.Accounts.user_to_map(updated))
  end
end
