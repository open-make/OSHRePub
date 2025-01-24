# SPDX-FileCopyrightText: © 2025 Contributors to the OSHRePub project
# SPDX-License-Identifier: AGPL-3.0-only

defmodule OSHRePub.Projects.SourceManager do
  use GenServer

  alias DialyxirVendored.Project
  alias Bandit.Pipeline
  alias Phoenix.PubSub

  require Logger

  alias OSHRePub.Repo
  alias OSHRePub.Projects.Project
  alias OSHRePub.Accounts.OAuthLink
  alias OSHRePub.Projects.Snapshot
  alias OSHRePub.Projects.Pipeline

  def projects_storage_dir(), do: Application.fetch_env!(:oshrepub, OSHRePub)[:projects_storage_dir]

  # Client

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{
      snapshot_tasks: %{},
      pipeline_tasks: %{},
    }, name: __MODULE__)
  end

  def run_pipeline(snapshot_id) do
    GenServer.call(__MODULE__, {:run_pipeline, snapshot_id})
  end

  def create_snapshot(project, vcs_selector) do
    GenServer.call(__MODULE__, {:create_snapshot, project, vcs_selector})
  end

  # Server (callbacks)

  def init(state) do
    PubSub.subscribe(OSHRePub.PubSub, "webhook")
    {:ok, state}
  end

  def handle_info(%{"event" => "push", "project_id" => project_id, "ref" => ref, "deleted" => false} = _params, state) do
    project = Repo.get_by(Project, id: project_id) |> Repo.preload([:owner])
    Logger.info("Received push for project #{project.id}")
    case ref do
      "refs/heads/" <> branch ->
        Logger.info("Got a branch: #{branch}")

        snapshot = s_create_snapshot(project, branch)

        PubSub.broadcast(OSHRePub.PubSub, "source_manager", {:source_snapshot_created, snapshot})
        {:noreply, state}
      "refs/tags/" <> tag ->
        Logger.info("Got a tag: #{tag}")

        snapshot = s_create_snapshot(project, tag)

        PubSub.broadcast(OSHRePub.PubSub, "source_manager", {:source_snapshot_created, snapshot})
        {:noreply, state}
      _ ->
        Logger.info(ref)
        {:noreply, state}
    end
  end

  def handle_info({ref, {:snapshot_created, snapshot}}, %{snapshot_tasks: tasks} = state) when is_map_key(tasks, ref) do
    # Prevent reception of process down message
    Process.demonitor(ref, [:flush])

    {caller, tasks} = Map.pop!(tasks, ref)
    send(caller, {:snapshot_created, snapshot})
    {:noreply, %{state | snapshot_tasks: tasks}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{snapshot_tasks: tasks} = state) when is_map_key(tasks, ref) do
    {caller, tasks} = Map.pop!(tasks, ref)
    send(caller, {:snapshot_creation_failed, reason})
    {:noreply, %{state | snapshot_tasks: tasks}}
  end

  def handle_info({ref, {:job_finished, pipeline_id}}, %{pipeline_tasks: tasks} = state) when is_map_key(tasks, ref) do
    # Prevent reception of process down message
    Process.demonitor(ref, [:flush])

    {{_pipeline_id, job_name, caller}, tasks} = Map.pop!(tasks, ref)
    Logger.info("Pipeline job finished: #{job_name}")

    pipeline = Repo.get_by(Pipeline, id: pipeline_id)
    jobs = pipeline.jobs |> Enum.map(fn %Pipeline.Job{name: name, state: state} -> if name == job_name, do: %{name: name, state: "Finished"}, else: %{name: name, state: state} end)

    update_data = %{jobs: jobs}

    {:ok, pipeline} = Repo.update(Pipeline.update_changeset(pipeline, update_data))

    send(caller, {:pipeline_updated, pipeline.id})
    {:noreply, %{state | pipeline_tasks: tasks}}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{pipeline_tasks: tasks} = state) when is_map_key(tasks, ref) do
    # FIXME: Implement this
    {{pipeline_id, job_name, caller}, tasks} = Map.pop!(tasks, ref)
    Logger.error("Pipeline job failed: #{job_name}")

    pipeline = Repo.get_by(Pipeline, id: pipeline_id)
    jobs = pipeline.jobs |> Enum.map(fn %Pipeline.Job{name: name, state: state} -> if name == job_name, do: %{name: name, state: "Failed"}, else: %{name: name, state: state} end)

    update_data = %{jobs: jobs}

    {:ok, pipeline} = Repo.update(Pipeline.update_changeset(pipeline, update_data))

    send(caller, {:pipeline_updated, pipeline.id})
    {:noreply, %{state | pipeline_tasks: tasks}}
  end

  def handle_info(info, state) do
    IO.inspect(info)
    {:noreply, state}
  end

  defp s_create_snapshot(project, vcs_selector) do
    snapshots_dir = Path.join([projects_storage_dir(), project.id, "snapshots"])
    File.mkdir_p!(snapshots_dir)

    tmp_dir = Path.join([snapshots_dir, UUIDv7.generate()])

    oauth_link = Repo.get_by(OAuthLink, type: "github", account_id: project.owner.id)
    {:ok, remote_username} = OAuthLink.fetch_remote_username(oauth_link)
    repository_url = "https://#{oauth_link.token}@github.com/#{remote_username}/#{project.name}"

    # FIXME: Find a way to not pass the token via command line
    {_, 0} = System.cmd("git", ["clone", "--quiet", "--branch=#{vcs_selector}", "--depth=1", "--recursive", repository_url, tmp_dir], stderr_to_stdout: true)
    {output, 0} = System.cmd("git", ["-C", tmp_dir, "rev-parse", "HEAD"], stderr_to_stdout: true)
    [[commit_hash]] = Regex.scan(~r/(\w*)\n/, output, capture: :all_but_first)
    IO.inspect(commit_hash)

    creation_data = %{
      vcs_selector: vcs_selector,
      vcs_uid: commit_hash,
      project_id: project.id
    }

    {:ok, snapshot} = Repo.insert(Snapshot.create_changeset(%Snapshot{}, creation_data))

    snapshot_dir = Path.join([snapshots_dir, snapshot.id])
    File.rename!(tmp_dir, snapshot_dir)

    snapshot
  end

  def handle_call({:create_snapshot, project, vcs_selector}, {caller, _}, state) do
    task =
      Task.Supervisor.async_nolink(OSHRePub.TaskSupervisor, fn ->
        snapshot = s_create_snapshot(project, vcs_selector)
        {:snapshot_created, snapshot}
      end)

    {:reply, :ok, %{state | snapshot_tasks: Map.put(state.snapshot_tasks, task.ref, caller)}}
  end

  def handle_call({:run_pipeline, snapshot_id}, {caller, _}, state) do
    snapshot = Repo.get_by(Snapshot, id: snapshot_id)

    creation_data = %{
      snapshot_id: snapshot_id,
      project_id: snapshot.project_id,
      jobs: [%{name: "osh-tool", state: "Pending"}, %{name: "gitbuilding", state: "Pending"}]
    }

    {:ok, pipeline} = Repo.insert(Pipeline.create_changeset(%Pipeline{}, creation_data))

    PubSub.broadcast(OSHRePub.PubSub, "source_manager", {:pipeline_created, pipeline})

    project_dir = Path.join(projects_storage_dir(), snapshot.project_id)
    snapshot_dir = Path.join([project_dir, "snapshots", snapshot.id])
    pipeline_dir = Path.join([project_dir, "pipelines", Integer.to_string(pipeline.id)])
    out_dir = Path.join([pipeline_dir, "out"])

    File.mkdir_p!(out_dir)

    # FIXME: report_gen leads to pandoc freeze when no network available.
    oshtool_task =
      Task.Supervisor.async_nolink(OSHRePub.TaskSupervisor, fn ->
        container_name = "pipeline-#{pipeline.id}--osh-tool"
        {_, 0} = System.cmd("docker", ["run", "--name", "#{container_name}", "-v", "#{snapshot_dir}:/data/in:ro", "osh-tool", "/bin/bash", "-c", "git config --global --add safe.directory /data/in && report_gen -C /data/in -o /data/out"], stderr_to_stdout: true)
        {_, 0} = System.cmd("docker", ["cp", "#{container_name}:/data/out", Path.join([out_dir, "osh-tool"])], stderr_to_stdout: true)
        {_, 0} = System.cmd("docker", ["rm", "#{container_name}"], stderr_to_stdout: true)
        {:job_finished, pipeline.id}
      end)

    gitbuilding_task =
      Task.Supervisor.async_nolink(OSHRePub.TaskSupervisor, fn ->
        container_name = "pipeline-#{pipeline.id}--gitbuilding"
        {_, 0} = System.cmd("docker", ["run", "--name", container_name, "--tmpfs", "/data/tmp", "-v", "#{snapshot_dir}:/data/in:ro", "--entrypoint", "/bin/bash", "gitbuilding", "-c", "cd /data/tmp && cp -a /data/in/* /data/tmp/ && /usr/local/bin/gitbuilding.sh build-html && mv /data/tmp/_site /data/out"], stderr_to_stdout: true)
        {_, 0} = System.cmd("docker", ["cp", "#{container_name}:/data/out", Path.join([out_dir, "gitbuilding"])], stderr_to_stdout: true)
        {_, 0} = System.cmd("docker", ["rm", "#{container_name}"], stderr_to_stdout: true)
        {:job_finished, pipeline.id}
      end)

    update_data = %{
      jobs: [%{name: "osh-tool", state: "Running"}, %{name: "gitbuilding", state: "Running"}]
    }

    {:ok, _} = Repo.update(Pipeline.update_changeset(pipeline, update_data))
    send(caller, {:pipeline_updated, pipeline.id})

    pipeline_tasks = state.pipeline_tasks
    |> Map.put(oshtool_task.ref, {pipeline.id, "osh-tool", caller})
    |> Map.put(gitbuilding_task.ref, {pipeline.id, "gitbuilding", caller})

    {:reply, :ok, %{state | pipeline_tasks: pipeline_tasks}}
  end
end
