defmodule EventStore.EventData do
  @moduledoc """
  EventData contains the data for a single event before being persisted to storage
  """

  defstruct [
    :correlation_id,
    :causation_id,
    :event_type,
    :data,
    :metadata,
  ]

  @type uuid :: String.t

  @type t :: %EventStore.EventData{
    correlation_id: uuid() | nil,
    causation_id: uuid() | nil,
    event_type: String.t,
    data: term,
    metadata: term | nil
  }

  def fetch(map, key) when is_map(map) do
    Map.fetch(map, key)
  end

  def get_and_update(map, key, fun) when is_map(map) do
    Map.get_and_update(map, key, fun)
  end
end
