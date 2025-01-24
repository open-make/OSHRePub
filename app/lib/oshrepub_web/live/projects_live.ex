# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.ProjectsLive do
  use OSHRePubWeb, :live_view

  require Logger

  import Ecto.Query

  alias OSHRePub.Repo
  alias OSHRePub.Accounts.OAuthLink
  alias OSHRePub.Projects.Project

  def mount(_params, _session, socket) do
    current_account_id = socket.assigns.current_account.id

    {:ok, assign(socket,
    available_source_repositories: [],
    owned_projects: Project |> where(owner_id: ^current_account_id) |> Repo.all
    )}
  end

  def render(assigns) do
    ~H"""
    <.header class="text-left p-4 border-b border-zinc-200 dark:border-zinc-700">
      Your Projects
    </.header>

    <div class="max-w-2xl mx-auto mt-4">

      <ul class="border-b border-zinc-200 dark:border-zinc-700 pb-2 flex flex-col items-center justify-center space-y-2">
        <%= for project <- @owned_projects do %>
          <li>
            <.link class="inline-block text-wisteria-600 hover:text-white border p-1 border-wisteria-600 hover:bg-wisteria-600"
                  href={~p"/#{@current_account.username}/#{project.name}"}>
              <p class="text-sm/6 font-semibold">{project.name}</p>
              <p class="text-xs/5">Source: {project.source_repository_html_url}</p>
            </.link>
          </li>
        <% end %>
      </ul>

      <div class="mt-4 flex justify-center border-none">
        <.button phx-click={
          show_modal("create_project_modal")
          |> JS.push("create_project_modal")
        }>Create project</.button>
      </div>
    </div>

    <.modal id="create_project_modal">
      <%= if !Enum.empty?(@available_source_repositories) do %>
        <div class="flex flex-col">
          <.header class="text-center">
            Available source repositories
          </.header>
          <ul class="flex flex-col justify-center border-none space-y-2">
            <%= for {repo, index} <- Enum.with_index(@available_source_repositories) do %>
              <li>
                <div class="flex flex-row space-x-4">
                  <.link class="inline-block text-wisteria-600 hover:text-white border p-1 border-wisteria-600 hover:bg-wisteria-600"
                        href={"#{repo["html_url"]}"} target="_blank">
                    <p class="text-sm/6 font-semibold">{repo["name"]}</p>
                    <p class="text-xs/5">Source: {repo["html_url"]}</p>
                  </.link>
                  <div class="p-0 my-auto">
                    <.button variant={:icon} phx-click={hide_modal("create_project_modal") |> JS.push("create_project")} phx-value-index={index} class="h-7 w-7 px-0 py-0"><.icon name="hero-plus" class="h-4 w-4" /></.button>
                  </div>
                </div>

              </li>
            <% end %>
          </ul>
        </div>
      <% end %>
    </.modal>
    """
  end

  defp fetch_all(url, headers) do
    {:ok, response} = HTTPoison.get(url, headers, [])

    {:ok, repos} = Jason.decode(response.body)
    case Enum.find(response.headers, fn {k, _v} -> k == "Link" end) do
      {_, v} ->
        case Regex.scan(~r/(?<=<)([\S]*)(?=>; rel="next")/, v, [capture: :first]) do
          [[next_url]] -> repos ++ fetch_all(next_url, headers)
          _ -> repos
        end
      _ -> repos
    end
  end

  def fetch_available_github_repositories(account_id) do
    oauth_link = Repo.get_by(OAuthLink, type: "github", account_id: account_id)

    url = "https://api.github.com/user/repos?per_page=30&page=1"
    headers = ["X-GitHub-Api-Version": "2022-11-28", "Accept": "application/vnd.github+json", "Authorization": "Bearer #{oauth_link.token}"]

    fetch_all(url, headers)
  end

  def handle_event("create_project_modal", _value, socket) do
    if Enum.empty?(socket.assigns.available_source_repositories) do
      github_repositories = fetch_available_github_repositories(socket.assigns.current_account.id)
      {:noreply, assign(socket, available_source_repositories: github_repositories)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("create_project", args, socket) do
    {index, _} =  Integer.parse(args["index"])
    repo = Enum.at(socket.assigns.available_source_repositories, index)

    owner = socket.assigns.current_account

    creation_data = %{
      owner_id: owner.id,
      name: repo["name"],
      source_repository_type: "github",
      source_repository_uid: repo["id"] |> to_string,
      source_repository_html_url: repo["html_url"],
      source_repository_git_url: repo["git_url"],
    }

    case Repo.get_by(Project, creation_data) do
      nil ->
        Logger.info("Creating new project")
        {:ok, project} = Repo.insert(Project.create_changeset(%Project{}, creation_data))

        oauth_link = Repo.get_by(OAuthLink, account_id: project.owner_id, type: project.source_repository_type) |> Repo.preload([:account])
        Project.create_webhook(oauth_link.token, project)

        {:noreply,
          socket
          |> assign(owned_projects: [project | socket.assigns.owned_projects])
          |> redirect(to: "/#{owner.username}/#{project.name}")
        }
      _ ->
        Logger.info("Found")
        {:noreply, socket |> put_flash(:error, "Project already exists")}
    end
  end
end
