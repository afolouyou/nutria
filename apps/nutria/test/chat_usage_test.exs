defmodule Nutria.ChatUsageTest do
  use Nutria.DataCase

  alias Nutria.Accounts
  alias Nutria.Chat.ChatUsage
  alias Nutria.Plans

  setup do
    {:ok, %{user: user}} =
      Accounts.register(%{
        "email" => "chat#{System.unique_integer([:positive])}@example.com",
        "password" => "senha123",
        "name" => "Chat"
      })

    %{user: user}
  end

  test "free plan has a 7/day chat limit", %{user: user} do
    assert Plans.chat_limit(:free) == 7
    assert ChatUsage.remaining_today(user.id, :free) == 7

    for n <- 6..0//-1 do
      assert {:ok, ^n} = ChatUsage.consume(user.id, :free)
    end

    assert {:blocked, 0} = ChatUsage.consume(user.id, :free)
  end

  test "paid plans are unlimited", %{user: user} do
    assert ChatUsage.remaining_today(user.id, :folha) == nil
    assert {:ok, nil} = ChatUsage.consume(user.id, :folha)
    assert {:ok, nil} = ChatUsage.consume(user.id, :laranja)
  end

  test "soft limits reset the daily counter instead of blocking", %{user: user} do
    Application.put_env(:nutria, :plans, soft_limits: true)
    on_exit(fn -> Application.put_env(:nutria, :plans, soft_limits: false) end)

    for n <- 6..0//-1, do: assert {:ok, ^n} = ChatUsage.consume(user.id, :free)

    assert {:ok, 6} = ChatUsage.consume(user.id, :free)
    assert ChatUsage.remaining_today(user.id, :free) == 6
  end
end
