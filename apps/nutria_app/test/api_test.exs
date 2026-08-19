defmodule NutriaWeb.ApiTest do
  use NutriaWeb.ConnCase

  alias Nutria.Accounts

  describe "GET /api/" do
    test "returns app info", %{conn: conn} do
      conn = get(conn, "/api/")
      assert %{"app" => "NutrIA", "status" => "ok"} = json_response(conn, 200)
    end
  end

  describe "authentication" do
    test "GET /api/auth/me without token returns 401", %{conn: conn} do
      conn = get(conn, "/api/auth/me")
      assert json_response(conn, 401)["detail"] == "Missing token"
    end

    test "register then access /api/auth/me with token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/auth/register",
          Jason.encode!(%{
            "email" => "api@example.com",
            "password" => "senha123",
            "name" => "API"
          })
        )

      assert %{"access_token" => token, "user" => %{"email" => "api@example.com"}} =
               json_response(conn, 200)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/auth/me")

      assert json_response(conn, 200)["email"] == "api@example.com"
    end

    test "login with wrong password returns 401", %{conn: conn} do
      {:ok, _} =
        Accounts.register(%{
          "email" => "login-api@example.com",
          "password" => "senha123",
          "name" => "Login"
        })

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post(
          "/api/auth/login",
          Jason.encode!(%{"email" => "login-api@example.com", "password" => "errada"})
        )

      assert json_response(conn, 401)
    end
  end

  describe "protected routes" do
    test "conversations and pantry require a token", %{conn: conn} do
      assert json_response(get(conn, "/api/conversations"), 401)["detail"] == "Missing token"
      assert json_response(get(conn, "/api/pantry/items"), 401)["detail"] == "Missing token"
    end
  end
end
