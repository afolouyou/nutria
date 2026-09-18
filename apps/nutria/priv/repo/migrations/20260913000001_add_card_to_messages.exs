defmodule Nutria.Repo.Migrations.AddCardToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :card, :jsonb
    end
  end
end