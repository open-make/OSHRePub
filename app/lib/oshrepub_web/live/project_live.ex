# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePubWeb.ProjectLive do

  use OSHRePubWeb, :live_view

  alias Phoenix.PubSub

  require Logger
  require CSV

  import OSHRePub.Accounts
  import Ecto.Query

  alias OSHRePub.Repo
  alias OSHRePub.Projects.Project
  alias OSHRePub.Accounts.OAuthLink
  alias OSHRePub.Projects.Snapshot
  alias OSHRePub.Projects.SourceManager
  alias OSHRePub.Projects.Pipeline
  alias OSHRePub.Reviews.Review

  def webhook_host(), do: Application.fetch_env!(:oshrepub, OSHRePub)[:webhook_host]

  def tab_class(tab, which_tab) do
    if tab == which_tab do
      "active"
    else
      ""
    end
  end

  def is_active_tab(tab, which_tab) do
    tab == which_tab
  end

  defp find_project(owner_username, projectname) when is_nil(owner_username) or is_nil(projectname), do: nil
  defp find_project(owner_username, projectname) do
    project_owner = get_account_by_username(owner_username)
    if project_owner do
      Repo.get_by(Project, owner_id: project_owner.id, name: projectname)
    end
  end

  def mount(%{"username" => username,
              "projectname" => projectname} = _params, _session, socket) do

    project = find_project(username, projectname) |> Repo.preload([:owner])
    if project do
      if project.owner_id == socket.assigns.current_account.id do
        if connected?(socket) do
          PubSub.subscribe(OSHRePub.PubSub, "source_manager")
        end

        oauth_link = Repo.get_by(OAuthLink, account_id: project.owner_id, type: project.source_repository_type) |> Repo.preload([:account])

        snapshots = Snapshot |> where(project_id: ^project.id) |> Repo.all
        {:ok, assign(socket,
          username: username,
          projectname: projectname,
          project: project,
          vcs_tags: Project.fetch_tags(oauth_link.token, project),
          tab: :reviews,
          snapshots: snapshots,
          pipelines: Pipeline |> where(project_id: ^project.id) |> Repo.all,
          reviews: snapshots
                   |> Repo.preload([:reviews])
                   |> Enum.map(fn snapshot -> snapshot.reviews end)
                   |> List.flatten,
          review_form: to_form(%{"tag" => nil}),
          debug_form: to_form(%{"snapshot" => nil}),
          creating_review_snapshot: false
        )}
      else
        raise OSHRePubWeb.ProjectLive.UnauthorizedError
      end
    else
      raise OSHRePubWeb.ProjectLive.InvalidProjectError
    end
  end

  defp parse_bom_csv(filename) do
    # columns: pos, name, units, type, reference
    File.stream!(filename)
    |> CSV.decode([headers: true, separator: ?\t])
    |> Enum.map(fn {:ok, row} -> %{position: row["POS"], name: row["NAME"], quantity: row["UNITS"] |> String.to_integer} end)
  end

  def handle_event("test", _value, socket) do
    Logger.info("test")
    project = socket.assigns.project
    oauth_link = Repo.get_by(OAuthLink, account_id: project.owner_id, type: project.source_repository_type) |> Repo.preload([:account])

    {:ok, _remote_username} = OAuthLink.fetch_remote_username(oauth_link)

    Project.clear_webhooks(oauth_link.token, project)

    {:noreply, socket}
  end

  def handle_event("request_review", %{"tag" => tag} = _params, socket) do
    project = socket.assigns.project

    Logger.info("Review requested for tag #{tag} of project #{project.name}")

    SourceManager.create_snapshot(project, tag)

    socket = socket |> assign(creating_review_snapshot: true)
    {:noreply, socket}
  end

  def handle_event("create_webhook", _value, socket) do
    project = socket.assigns.project
    oauth_link = Repo.get_by(OAuthLink, account_id: project.owner_id, type: project.source_repository_type) |> Repo.preload([:account])

    Project.create_webhook(oauth_link.token, project)

    {:noreply, socket}
  end

  def handle_event("delete_webhook", _value, socket) do
    project = socket.assigns.project
    oauth_link = Repo.get_by(OAuthLink, account_id: project.owner_id, type: project.source_repository_type) |> Repo.preload([:account])

    Project.clear_webhooks(oauth_link.token, project)

    {:noreply, socket}
  end

  def handle_event("simulate_webhook_push", _value, socket) do
    project = socket.assigns.project

    PubSub.broadcast(OSHRePub.PubSub, "webhook", %{
      "event" => "push",
      "project_id" => project.id,
      "ref" => "refs/heads/main",
      "head_commit" => %{"id" => ""},
      "deleted" => false
      })
    {:noreply, socket}
  end

  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, tab: String.to_atom(tab))}
  end

  def handle_event("run_pipeline", %{"snapshot" => snapshot_id} = _params, socket) do
    OSHRePub.Projects.SourceManager.run_pipeline(snapshot_id)
    {:noreply, socket}
  end

  def handle_info({:source_snapshot_created, snapshot} = _info, socket) when snapshot.project_id == socket.assigns.project.id do
    {:noreply, assign(socket, snapshots: socket.assigns.snapshots ++ [snapshot])}
  end

  def handle_info({:pipeline_created, pipeline} = _info, socket) when pipeline.project_id == socket.assigns.project.id do
    {:noreply, assign(socket, pipelines: socket.assigns.pipelines ++ [pipeline])}
  end

  def handle_info({:snapshot_created, snapshot}, socket) do
    snapshot_dir = Path.join([SourceManager.projects_storage_dir(), snapshot.project_id, "snapshots", snapshot.id])

    socket = socket |> assign(snapshots: socket.assigns.snapshots ++ [snapshot], creating_review_snapshot: false)

    bom_filename = Path.join([snapshot_dir, "BoM.csv"])
    if File.exists?(bom_filename) do
      changeset = Review.create_changeset(%Review{}, %{
        snapshot_id: snapshot.id,
        parts: parse_bom_csv(bom_filename)
      })

      {:ok, review} = Repo.insert(changeset)

      {:noreply, socket |> assign(reviews: socket.assigns.reviews ++ [review])}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:snapshot_creation_failed, _reason}, socket) do
    socket = socket
    |> assign(creating_review_snapshot: false)
    |> put_flash(:error, "Failed to create snapshot")

    {:noreply, socket}
  end

  def handle_info({:pipeline_updated, _pipeline_id}, socket) do
    # FIXME: Update single pipeline instead of reloading all.
    {:noreply, socket |> assign(pipelines: Pipeline |> where(project_id: ^socket.assigns.project.id) |> Repo.all)}
  end

  def handle_info(info, socket) do
    IO.inspect(info)
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.header class="text-left p-4 border-b border-zinc-200 dark:border-zinc-700">
      {@project.name}
    </.header>

    <div class="max-w-4xl mx-auto divide-y mt-10 text-center">

      <nav class="mb-2 border-b border-zinc-200 dark:border-zinc-700 bg-zinc-100 dark:bg-zinc-800 px-4">
        <div>
          <ul class="list-none space-x-2 m-0 p-0 overflow-hidden top-0 w-full">
            <li class="float-left mb-0"><button class={"p-1 block text-center text-zinc-700 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100 #{if @tab == :reviews, do: "bg-zinc-200 dark:bg-zinc-800", else: "hover:bg-zinc-50 dark:hover:bg-zinc-500"}"} aria-current={if @tab == :reviews, do: "true", else: "false"} phx-click="change_tab" phx-value-tab="reviews">Reviews</button></li>
            <li class="float-right mb-0"><button class={"p-1 block text-center text-zinc-700 hover:text-zinc-900 dark:text-zinc-300 dark:hover:text-zinc-100 #{if @tab == :debug, do: "bg-zinc-200 dark:bg-zinc-800", else: "hover:bg-zinc-50 dark:hover:bg-zinc-500"}"} aria-current={if @tab == :debug, do: "true", else: "false"} phx-click="change_tab" phx-value-tab="debug">Debug</button></li>
          </ul>
        </div>
      </nav>

      <%= if is_active_tab(@tab, :debug) do %>

        <div class="flex flex-row space-x-2 mt-4">

          <div class="flex flex-col gap-1 max-w-xs mx-auto border-none">
            <h2 class="text-lg border-none font-semibold leading-8 text-zinc-800 dark:text-zinc-50">Triggers</h2>

            <!--
            <.button phx-click="create_webhook">Create webhook</.button>
            <.button phx-click="delete_webhook">Delete webhook</.button>
            -->

            <.button phx-click="simulate_webhook_push">Simulate webhook push</.button>

            <!--
            <.button phx-click="test">Test</.button>
            -->

            <.simple_form
              for={@debug_form}
              id="debug_form"
              phx-submit="run_pipeline"
              class="border p-2"
            >
              <.input
                field={@debug_form[:snapshot]}
                type="select"
                label="Snapshot"
                options={Enum.map(@snapshots, &(&1.id))}
              />
              <:actions>
                <.button>Run pipeline</.button>
              </:actions>
            </.simple_form>
          </div>

          <div>
            <h2 class="text-lg border-none font-semibold leading-8 text-zinc-800 dark:text-zinc-50">Snapshots</h2>
            <ul class="pb-2 border-none space-y-2">
              <%= for snapshot <- @snapshots do %>
                <li>
                  <div class="inline-block  text-zinc-800 dark:text-zinc-50 border p-1">
                    <p class="text-sm/6 font-semibold">VCS Selector: {snapshot.vcs_selector}</p>
                    <p class="text-xs/5">VCS uid: {snapshot.vcs_uid}</p>
                    <p class="text-xs/5">Id: {snapshot.id}</p>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>

          <div>
            <h2 class="text-lg border-none font-semibold leading-8 text-zinc-800 dark:text-zinc-50">Pipelines</h2>
            <ul class="pb-2 border-none space-y-2">
              <%= for pipeline <- @pipelines do %>
                <li>
                  <div class="inline-block  text-zinc-800 dark:text-zinc-50 border items-center text-center flex flex-col p-1">
                    <p class="text-sm/6 font-semibold">Snapshot: {pipeline.snapshot_id}</p>
                    <p class="text-xs/5">Id: {pipeline.id}</p>
                    <div class="flex flex-row items-center text-center space-x-4"><div class="text-sm/6 font-semibold ">Jobs:</div>
                    <table class="table-auto border-collapse border">
                      <thead>
                        <tr>
                          <th class="border bg-zinc-100 dark:bg-zinc-700">Name</th>
                          <th class="border bg-zinc-100 dark:bg-zinc-700">State</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for job <- pipeline.jobs do %>
                          <tr>
                            <td class="border">{job.name}</td>
                            <td class="border">
                            <%= if job.state == "Finished" do %>
                              <.link  class="text-wisteria-600 font-semibold" href={~p"/#{@username}/#{@projectname}/pipelines/#{pipeline.id}/#{job.name}"} target="_blank">
                                {job.state}
                              </.link>
                            <% else %>
                              {job.state}
                            <% end %>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table></div>
                  </div>
                </li>
              <% end %>
            </ul>
          </div>
        </div>
      <% end %>

      <%= if is_active_tab(@tab, :reviews) do %>
        <div class="flex flex-col gap-1 max-w-xs mx-auto border-none">
          <h2 class="text-lg border-none font-semibold leading-8 text-zinc-800 dark:text-zinc-50">Reviews</h2>

            <ul class="pb-2 border-none space-y-2">
              <%= for review <- @reviews do %>
                <li>
                  <.link class="inline-block  text-zinc-800 dark:text-zinc-50 border p-1" href={~p"/#{@username}/#{@projectname}/reviews/#{review.id}"}>
                    <p class="text-sm/6 font-semibold">Snapshot: {review.snapshot_id}</p>
                    <p class="text-xs/5">Id: {review.id}</p>
                  </.link>
                </li>
              <% end %>
            </ul>

            <.simple_form
              for={@review_form}
              id="review_form"
              phx-submit="request_review"
              class="border p-2"
            >
              <.input
                field={@review_form[:tag]}
                type="select"
                label="Tag"
                options={Enum.map(@vcs_tags, fn tag -> tag["name"] end)}
              />
              <:actions>
                <.button disabled={@creating_review_snapshot} phx-disable-with>
                <div class={[!@creating_review_snapshot && "hidden", "phx-submit-loading:flex items-center justify-center", @creating_review_snapshot && "flex"]}>
                <.icon name="hero-arrow-path" class="ml-1 mr-3 h-3 w-3 animate-spin" />
                  Creating review
                </div>
                <div :if={!@creating_review_snapshot} class="phx-submit-loading:hidden">
                  Request review
                </div>
                </.button>
              </:actions>
            </.simple_form>
        </div>
      <% end %>
    </div>

    """
  end
end

defmodule OSHRePubWeb.ProjectLive.InvalidProjectError do
  defexception message: "Invalid project", plug_status: 404
end

defmodule OSHRePubWeb.ProjectLive.UnauthorizedError do
  defexception message: "Project not owned", plug_status: 403
end
