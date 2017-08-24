defmodule EventStore.Registration.LocalRegistry do
  @moduledoc """
  Local process registration, restricted to a single node, using Elixir's [Registry](https://hexdocs.pm/elixir/Registry.html)
  """

  @behaviour EventStore.Registration

  alias EventStore.Registration.LocalRegistry.Supervisor

  def child_spec do
    [
      Supervisor.child_spec([]),
    ]
  end

  @doc """
  Starts a process using the given module/function/args parameters, and registers the pid with the given name.
  """
  @spec register_name(name :: term, module :: atom, function :: atom, args :: [term]) :: {:ok, pid} | {:error, term}
  @impl EventStore.Registration
  def register_name(name, module, fun, [supervisor, args]) do
    name = {:via, Registry, {EventStore.Registration.LocalRegistry, name}}

    apply(module, fun, [supervisor, args ++ [[name: name]]])
  end

  @doc """
  Get the pid of a registered name.
  """
  @spec whereis_name(name :: term) :: pid | :undefined
  @impl EventStore.Registration
  def whereis_name(name)
  def whereis_name(EventStore.Publisher), do: Process.whereis(EventStore.Publisher)
  def whereis_name(name), do: Registry.whereis_name({EventStore.Registration.LocalRegistry, name})

  @doc """
  Joins the current process to a group
  """
  @spec join(group :: term) :: :ok
  @impl EventStore.Registration
  def join(group)
  def join(EventStore.Publisher), do: :ok
  def join(group) do
    {:ok, _} = Registry.register(EventStore.Subscriptions.PubSub, group, [])
    :ok
  end

  @doc """
  Publishes a message to a group.
  """
  @spec publish(group :: term, msg :: term) :: :ok
  @impl EventStore.Registration
  def publish(group, msg)
  def publish(EventStore.Publisher, msg), do: send(EventStore.Publisher, msg)
  def publish(group, msg) do
    Registry.dispatch(EventStore.Subscriptions.PubSub, group, fn entries ->
      for {pid, _} <- entries, do: send(pid, msg)
    end)
  end

  @doc """
  Gets all the members of a group. Returns a list of pids.
  """
  @spec members(group :: term) :: [pid]
  @impl EventStore.Registration
  def members(group) do
    for {pid, _} <- Registry.lookup(EventStore.Subscriptions.PubSub, group), do: pid
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      def via_tuple(EventStore.Publisher), do: EventStore.Publisher
      def via_tuple(name), do: {:via, Registry, {EventStore.Registration.LocalRegistry, name}}
    end
  end
end