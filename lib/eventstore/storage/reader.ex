defmodule EventStore.Storage.Reader do
  require Logger

  alias EventStore.EventData
  alias EventStore.Sql.Statements
  alias EventStore.Storage.Reader
  
  def read_forward(conn, stream_id, start_version, count \\ nil) do
    case Reader.Query.read_events_forward(conn, stream_id, start_version) do
      {:ok, rows} -> map_rows_to_event_data(rows)
      {:error, reason} -> failed_to_read(stream_id, reason)
    end
  end

  defp map_rows_to_event_data(rows) do
    event_data = Reader.EventAdapter.to_event_data(rows)
    {:ok, event_data}
  end

  defp failed_to_read(stream_id, reason) do
    Logger.warn "failed to read events from stream id #{stream_id} due to #{reason}"
    {:error, reason}
  end

  defmodule EventAdapter do
    def to_event_data(rows) do
      rows
      |> Enum.map(&to_event_data_from_row/1)
      |> Enum.map(&decode_headers/1)
      |> Enum.map(&decode_payload/1)
    end

    def to_event_data_from_row([event_id, stream_id, stream_version, event_type, correlation_id, headers, payload, created_at]) do
      %EventData{
        event_id: event_id,
        stream_id: stream_id,
        stream_version: stream_version,
        event_type: event_type,
        correlation_id: correlation_id,
        headers: headers,
        payload: payload,
        created_at: created_at
      }
    end

    defp decode_headers(%EventData{headers: headers} = event) do
      %EventData{event | headers: Poison.decode!(headers)}
    end

    defp decode_payload(%EventData{payload: payload} = event) do
      event_type = event_type_to_struct(event)

      %EventData{event | payload: Poison.decode!(payload, as: event_type)}
    end

    @doc """
    Convert the string representation of the event type to an Elixir atom and struct
    """
    defp event_type_to_struct(%EventData{event_type: event_type}) do
      event_type
      |> String.to_atom
      |> struct
    end
  end

  defmodule Query do
    def read_events_forward(conn, stream_id, start_version) do
      conn
      |> Postgrex.query(Statements.read_events_forward, [stream_id, start_version])
      |> handle_response
    end

    defp handle_response({:ok, %Postgrex.Result{num_rows: 0}}) do
      {:ok, []}
    end

    defp handle_response({:ok, %Postgrex.Result{rows: rows}} = result) do
      {:ok, rows}
    end
  end
end
