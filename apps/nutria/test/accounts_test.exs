defmodule Nutria.AccountsTest do
  use Nutria.DataCase

  alias Nutria.Accounts
  alias Nutria.Accounts.User

  describe "register/1" do
    test "creates user and returns token" do
      assert {:ok, %{user: %User{email: "joao@example.com"}, token: token}} =
               Accounts.register(%{
                 "email" => "joao@example.com",
                 "password" => "senha123",
                 "name" => "João"
               })

      assert token != ""
    end

    test "downcases email" do
      assert {:ok, %{user: user}} =
               Accounts.register(%{
                 "email" => "Maria@Example.com",
                 "password" => "senha123",
                 "name" => "Maria"
               })

      assert user.email == "maria@example.com"
    end

    test "rejects duplicate email" do
      attrs = %{"email" => "dup@example.com", "password" => "senha123", "name" => "Dup"}

      assert {:ok, _} = Accounts.register(attrs)
      assert {:error, :bad_request, _} = Accounts.register(attrs)
    end
  end

  describe "login/2" do
    setup do
      {:ok, %{user: user}} =
        Accounts.register(%{
          "email" => "login@example.com",
          "password" => "senha123",
          "name" => "Login"
        })

      %{user: user}
    end

    test "returns token with valid credentials", %{user: user} do
      assert {:ok, %{user: logged_user, token: token}} = Accounts.login(user.email, "senha123")
      assert logged_user.id == user.id
      assert token != ""
    end

    test "downcases email on login", %{user: user} do
      assert {:ok, _} = Accounts.login("LOGIN@example.com", "senha123")
      assert user.email == "login@example.com"
    end

    test "rejects wrong password", %{user: user} do
      assert {:error, :unauthorized, _} = Accounts.login(user.email, "errada")
    end

    test "rejects unknown email" do
      assert {:error, :unauthorized, _} = Accounts.login("naoexiste@example.com", "senha123")
    end
  end

  describe "social_login/3" do
    test "creates user on first login" do
      assert {:ok, %{user: user}} =
               Accounts.social_login("social@example.com", "Social", "google")

      assert user.provider == "google"
    end

    test "reuses existing user on second login" do
      assert {:ok, %{user: first}} =
               Accounts.social_login("social2@example.com", "Social", "google")

      assert {:ok, %{user: second}} =
               Accounts.social_login("social2@example.com", "Social", "google")

      assert first.id == second.id
    end

    test "rejects invalid provider" do
      assert {:error, :bad_request, _} = Accounts.social_login("x@example.com", "X", "twitter")
    end
  end
end
