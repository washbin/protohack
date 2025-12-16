defmodule Protohack.BFormat do
  @moduledoc """
  Solution for challenge 2: Means to an End of Protohackers
  """

  use GenServer

  require Logger

  @opts [
    :binary,
    active: false,
    reuseaddr: true
  ]

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port)
  end

  @impl GenServer
  def init(port) do
    case :gen_tcp.listen(port, @opts) do
      {:ok, listen_socket} ->
        Logger.info("Accepting connections for means to an end on port #{port}")
        Task.start_link(fn -> loop_acceptor(listen_socket) end)
        state = %{listen_socket: listen_socket}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp loop_acceptor(ls_socket) do
    case :gen_tcp.accept(ls_socket) do
      {:ok, client} ->
        Task.start(fn -> serve(client, []) end)
        loop_acceptor(ls_socket)

      {:error, _reason} ->
        # Logger.error("Accept failed #{inspect(reason)}")
        :ok
    end
  end

  defp serve(socket, store) do
    # receive 9 bytes
    case(:gen_tcp.recv(socket, 9)) do
      # destructure, first byte is symbol I or Q,
      # 4 bytes are signed integer in big endian ordering
      # rest 4 bytes are also signed integer in big endian ordering
      {:ok, data} ->
        <<type::bytes-size(1), first_arg::big-signed-integer-size(32),
          second_arg::big-signed-integer-size(32)>> =
          data

        new_store =
          case type do
            "I" ->
              insert_item(store, first_arg, second_arg)

            "Q" ->
              mean = query_mean(store, first_arg, second_arg)
              binval = <<mean::big-signed-integer-size(32)>>
              :gen_tcp.send(socket, binval)
              store

            _ ->
              store
          end

        serve(socket, new_store)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        # Logger.debug("Error receiving data: #{inspect(reason)}")
        :ok
    end
  end

  defp insert_item(store, key, value) do
    [{key, value} | store]
  end

  defp query_mean(store, first_key, second_key) do
    data_in_between =
      Enum.filter(store, fn {key, _} ->
        first_key <= key and key <= second_key
      end)

    if data_in_between == [] do
      0
    else
      mean =
        Enum.sum_by(data_in_between, fn {_, value} -> value end) / Enum.count(data_in_between)

      trunc(mean)
    end
  end
end
