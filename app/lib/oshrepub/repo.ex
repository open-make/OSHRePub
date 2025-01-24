# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Repo do
  use Ecto.Repo,
    otp_app: :oshrepub,
    adapter: Ecto.Adapters.Postgres
end
