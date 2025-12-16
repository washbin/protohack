defmodule Protohack.TestSmokeTest do
  use ExUnit.Case, async: true

  @socket_options [:binary, active: false, reuseaddr: true]
  @port 8989

  setup do
    Process.sleep(1000)
  end

  test "server echoes back" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", @port, @socket_options)

    msg = "hello"
    :gen_tcp.send(socket, msg)
    assert :gen_tcp.recv(socket, 0, 1000) == {:ok, msg}
  end
end
