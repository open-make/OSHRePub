# SPDX-FileCopyrightText: 2024-2025 OSHRePub contributors
# SPDX-FileCopyrightText: Copyright (c) 2024 PureType Systems Ltd
# SPDX-License-Identifier: MIT

defmodule OSHRePubWeb.Plugs.GithubWebhook do

  @moduledoc """
  Handles incoming GitHub hook requests
  """

  import Plug.Conn

  require Logger

  @behaviour Plug

  defmodule CacheBodyReader do
    @moduledoc false

    def read_body(conn, opts) do
      {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
      conn = update_in(conn.assigns[:raw_body], &[body | &1 || []])
      {:ok, body, conn}
    end
  end

  @plug_parser Plug.Parsers.init(
                 parsers: [:json],
                 body_reader: {CacheBodyReader, :read_body, []},
                 json_decoder: Application.compile_env(:phoenix, :json_library, Jason)
               )

  def init(options) do
    options
  end

  def call(conn, options) do
    path = options[:path]

    case conn.request_path do
      ^path ->
        secret = case options[:secret] do
          {:system, env_key} ->
            System.get_env(env_key)
          secret ->
            secret
        end
        {module, function} = options[:action]

        conn = Plug.Parsers.call(conn, @plug_parser)

        [signature_in_header] = get_req_header(conn, "x-hub-signature-256")

        if verify_signature(conn.assigns.raw_body, secret, signature_in_header) do
          apply(module, function, [conn, conn.params])
          conn |> send_resp(200, "OK") |> halt()
        else
          conn |> send_resp(403, "Forbidden") |> halt()
        end

      _ ->
        conn
    end
  end

  defp verify_signature(payload, secret, signature_in_header) do
    signature =
      "sha256=" <> (:crypto.mac(:hmac, :sha256, secret, payload) |> Base.encode16(case: :lower))

    Plug.Crypto.secure_compare(signature, signature_in_header)
  end
end
