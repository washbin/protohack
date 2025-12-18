defmodule Protohack.UnusualDatabase do
  @moduledoc """
  Solution for Unusual database program problem of Protohackers
  """

  use GenServer
  require Logger

  @opts [
    :binary,
    active: false,
    reuseaddr: true,
    buffer: 1024
  ]

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port)
  end

  @impl GenServer
  def init(port) do
    case :gen_udp.open(port, @opts) do
      {:ok, listen_socket} ->
        Logger.info("Port #{port} open for unusual database program")

        Task.start_link(fn ->
          loop_acceptor(listen_socket, %{"version" => "Unusual Database v0.1.0"})
        end)

        state = %{listen_socket: listen_socket}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp loop_acceptor(ls_socket, db) do
    case :gen_udp.recv(ls_socket, 1000) do
      {:ok, data} ->
        {req_address, req_port, packet} = data

        case parse_input(packet) do
          {:insert, key, val} when key != "version" ->
            new_db = Map.put(db, key, val)
            loop_acceptor(ls_socket, new_db)

          {:retrieve, key} ->
            val = Map.get(db, key, "")

            :gen_udp.send(ls_socket, req_address, req_port, "#{key}=#{val}")
            loop_acceptor(ls_socket, db)

          _ ->
            loop_acceptor(ls_socket, db)
        end

      {:error, reason} ->
        Logger.debug("Got error #{inspect(reason)}")
    end
  end

  defp parse_input(input) do
    if String.contains?(input, "=") do
      [key, val] = String.split(input, "=", parts: 2)
      {:insert, key, val}
    else
      {:retrieve, String.trim_trailing(input, "\n")}
    end
  end
end
