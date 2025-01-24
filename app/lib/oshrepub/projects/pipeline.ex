# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Projects.Pipeline do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pipelines" do
    belongs_to :project, OSHRePub.Projects.Project, type: :binary_id

    field :snapshot_id, :binary_id

    embeds_many :jobs, Job, primary_key: false, on_replace: :delete do
      field :name, :string
      field :state, :string
    end

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(pipeline, attrs, _opts \\ []) do
    pipeline
    |> cast(attrs, [:project_id, :snapshot_id])
    |> cast_embed(:jobs, with: &create_job_changeset/2)
  end

  def update_changeset(pipeline, attrs, _opts \\ []) do
    pipeline
    |> cast(attrs, [:id])
    |> cast_embed(:jobs, with: &create_job_changeset/2)
  end

  def create_job_changeset(schema, params) do
    schema
    |> cast(params, [:name, :state])
  end
end
