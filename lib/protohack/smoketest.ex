defmodule Protohack.SmokeTest do
  @moduledoc """
  Solution to Challenge 0: Smoketest
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
        Logger.info("Accepting connections for smoke test on port #{port}")
        Task.start_link(fn -> loop_acceptor(listen_socket) end)
        {:ok, %{listen_socket: listen_socket}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp loop_acceptor(ls_socket) do
    case :gen_tcp.accept(ls_socket) do
      {:ok, client} ->
        Task.start(fn -> serve(client) end)
        loop_acceptor(ls_socket)

      {:error, _reason} ->
        # Logger.error("Accept failed #{inspect(reason)}")
        :ok
    end
  end

  defp serve(socket) do
    case read_line(socket) do
      {:ok, data} ->
        :gen_tcp.send(socket, data)
        serve(socket)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        # Logger.error("Read failed #{inspect(reason)}")
        :ok
    end
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end
end
