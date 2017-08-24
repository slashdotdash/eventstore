defmodule EventStore.Registration.Distributed do
  @moduledoc """
  Process registration and distribution throughout a cluster of nodes using [Swarm](https://github.com/bitwalker/swarm)
  """

  @behaviour EventStore.Registration

  def child_spec, do: []

  @doc """
  Starts a process using the given module/function/args parameters, and registers the pid with the given name.
  """
  @spec register_name(name :: term, module :: atom, function :: atom, args :: [term]) :: {:ok, pid} | {:error, term}
  @impl EventStore.Registration
  def register_name(name, module, fun, args) do
    case Swarm.register_name(name, module, fun, args) do
      {:error, {:already_registered, pid}} -> {:error, {:already_started, pid}}
      reply -> reply
    end
  end

  @doc """
  Get the pid of a registered name.
  """
  @spec whereis_name(name :: term) :: pid | :undefined
  @impl EventStore.Registration
  def whereis_name(name), do: Swarm.whereis_name(name)

  @doc """
  Joins the current process to a group
  """
  @spec join(group :: term) :: :ok
  @impl EventStore.Registration
  def join(group)

  def join(EventStore.Publisher) do
    # Swarm requires a process to be registered before it may join a group
    with :yes <- Swarm.register_name("EventStore.Publisher.#{UUID.uuid4()}", self()) do
      Swarm.join(EventStore.Publisher, self())
    end
  end

  def join(group), do: Swarm.join(group, self())

  @doc """
  Publishes a message to a group.
  """
  @spec publish(group :: term, msg :: term) :: :ok
  @impl EventStore.Registration
  def publish(group, msg), do: Swarm.publish(group, msg)

  @doc """
  Gets all the members of a group. Returns a list of pids.
  """
  @spec members(group :: term) :: [pid]
  @impl EventStore.Registration
  def members(group), do: Swarm.members(group)

  defmacro __using__(_opts) do
    quote location: :keep do
      def via_tuple(name), do: {:via, :swarm, name}

      # Shutdown the process when a cluster toplogy change indicates it is now running on the wrong host.
      # This is to prevent a spike in process restarts as they are moved. Instead, allow the process to
      # be started on request.
      def handle_call({:swarm, :begin_handoff}, _from, state) do
        {:stop, :shutdown, :ignore, state}
      end

      def handle_cast({:swarm, :end_handoff, _state}, state) do
        {:noreply, state}
      end

      # Take the remote process state after net split has been resolved
      def handle_cast({:swarm, :resolve_conflict, state}, _state) do
        {:noreply, state}
      end

      # Stop the process as it is being moved to another node, or there are not currently enough nodes running
      def handle_info({:swarm, :die}, state) do
        {:stop, :shutdown, state}
      end
    end
  end
end