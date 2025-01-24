# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.PipelineController do
  use OSHRePubWeb, :controller

  import OSHRePub.Accounts

  alias OSHRePub.Repo
  alias OSHRePub.Projects.Project
  alias OSHRePub.Projects.SourceManager

  require Logger

  defp find_project(owner_username, projectname) when is_nil(owner_username) or is_nil(projectname), do: nil
  defp find_project(owner_username, projectname) do
    project_owner = get_account_by_username(owner_username)
    if project_owner do
      Repo.get_by(Project, owner_id: project_owner.id, name: projectname)
    end
  end

  def handle(conn, %{"username" => username, "projectname" => projectname, "pipeline_id" => pipeline_id} = _params) do

    project = find_project(username, projectname)
    if project do
      pipeline_dir = Path.join([SourceManager.projects_storage_dir(), project.id, "pipelines", pipeline_id])
      #osh_html_report = Path.join([pipeline_dir, "out", "osh-tool", "osh-report.html"])
      gitbuilding_html_site = Path.join([pipeline_dir, "out", "gitbuilding", "index.html"])

      conn
      |> put_resp_header("content-type", "text/html; charset=utf-8")
      |> send_file(200, gitbuilding_html_site)
    else
      conn
      |> Plug.Conn.send_resp(400, [])
      |> Plug.Conn.halt()
    end
  end

  def view_job(conn, %{"username" => username, "projectname" => projectname, "pipeline_id" => pipeline_id, "jobname" => jobname, "jobpath" => jobpath} = params) do
    IO.inspect(params)
    project = find_project(username, projectname)
    if project do
      pipeline_dir = Path.join([SourceManager.projects_storage_dir(), project.id, "pipelines", pipeline_id])
      #osh_html_report = Path.join([pipeline_dir, "out", "osh-tool", "osh-report.html"])
      job_output_path = Path.join([pipeline_dir, "out", jobname, jobpath] |> List.flatten)

      #content_type = opts[:content_type] || case Path.extname(job_output_path) do
      content_type = case Path.extname(job_output_path) do
        "." <> ext -> MIME.type(ext)
        _ -> "application/octet-stream"
      end

      if File.exists?(job_output_path) do
        Logger.info("Sending file #{job_output_path}")
        conn
        #|> put_resp_header("content-type", "text/html; charset=utf-8")
        |> put_resp_content_type(content_type)
        |> send_file(conn.status || 200, job_output_path)
      else
        Logger.error("Failed to find file #{job_output_path}")
        conn
        |> Plug.Conn.send_resp(404, [])
        |> Plug.Conn.halt()
      end
    else
      conn
      |> Plug.Conn.send_resp(400, [])
      |> Plug.Conn.halt()
    end
  end

  def view_job(conn, %{"username" => username, "projectname" => projectname, "pipeline_id" => _pipeline_id, "jobname" => _jobname} = _params) do
    project = find_project(username, projectname)
    if project do
      conn
      |> redirect(to: Path.join([current_path(conn), "index.html"]))
    else
      conn
      |> Plug.Conn.send_resp(400, [])
      |> Plug.Conn.halt()
    end
  end
end
