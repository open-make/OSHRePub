# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Reviews.Review do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, UUIDv7, autogenerate: true}

  schema "reviews" do
    belongs_to :snapshot, OSHRePub.Projects.Snapshot, type: :binary_id

    embeds_many :parts, Part do
      field :position, :string
      field :name, :string
      field :quantity, :integer
    end

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def create_changeset(schema, params) do
    schema
    |> cast(params, [:snapshot_id])
    |> cast_embed(:parts, with: &create_part_changeset/2)
  end

  defp create_part_changeset(schema, params) do
    schema
    |> cast(params, [:position, :name, :quantity])
  end
end
