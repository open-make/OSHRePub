# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Projects.Snapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias OSHRePub.Reviews.Review

  @primary_key {:id, UUIDv7, autogenerate: true}

  schema "snapshots" do
    field :vcs_selector, :string
    field :vcs_uid, :string

    belongs_to :project, OSHRePub.Projects.Project, type: :binary_id

    has_many :reviews, Review

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(snapshot, attrs, _opts \\ []) do
    snapshot
    |> cast(attrs, [:project_id, :vcs_selector, :vcs_uid])
  end
end
