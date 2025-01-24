# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Repo.Migrations.CreateAccountTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :username, :citext, null: false

      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :naive_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:accounts, [:username])
    create unique_index(:accounts, [:email])


    create table(:user_tokens) do
      add :account_id, references(:accounts, on_delete: :delete_all, type: :binary_id), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:account_id])
    create unique_index(:user_tokens, [:context, :token])


    create table(:oauth_links) do
      add :account_id, references(:accounts, on_delete: :delete_all, type: :binary_id), null: false

      add :type, :string
      add :remote_uid, :string
      add :token, :string

      add :allows_login, :boolean

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:oauth_links, [:account_id])


    create table(:projects, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :owner_id, references(:accounts, on_delete: :delete_all, type: :binary_id), null: false

      add :name, :string, null: false

      add :source_repository_type, :string, null: false
      add :source_repository_uid, :string, null: false
      add :source_repository_html_url, :string, null: false
      add :source_repository_git_url, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:projects, [:owner_id])


    create table(:snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :project_id, references(:projects, on_delete: :delete_all, type: :binary_id), null: false

      add :vcs_selector, :string, null: false
      add :vcs_uid, :string, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:snapshots, [:project_id])


    create table(:pipelines) do
      add :project_id, references(:projects, on_delete: :delete_all, type: :binary_id), null: false

      add :snapshot_id, references(:snapshots, on_delete: :delete_all, type: :binary_id), null: false

      add :jobs, :map

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:pipelines, [:project_id])
    create index(:pipelines, [:snapshot_id])

    create table(:reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true, null: false

      add :snapshot_id, references(:snapshots, on_delete: :delete_all, type: :binary_id), null: false

      add :parts, :map

      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
