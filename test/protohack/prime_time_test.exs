defmodule Protohack.PrimeTimeTest do
  use ExUnit.Case, async: true

  @socket_options [:binary, active: false, reuseaddr: true, packet: :line]
  @port 8990

  test "server returns well-formed for one well-formed input" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", @port, @socket_options)

    :gen_tcp.send(socket, JSON.encode!(%{"method" => "isPrime", "number" => 123}) <> "\n")
    {:ok, msg} = :gen_tcp.recv(socket, 0, 10_000)

    assert JSON.decode!(msg) == %{"method" => "isPrime", "prime" => false}
  end

  test "server returns well-formed for multiple consecutive well-formed input" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", @port, @socket_options)

    msg = ~s({"method":"isPrime","number":123}\n{"method":"isPrime","number":17})
    :gen_tcp.send(socket, msg <> "\n")

    expected_resp = ~s({"method":"isPrime","prime":false}\n)
    {:ok, resp} = :gen_tcp.recv(socket, 0, 10_000)
    assert resp == expected_resp

    next_expected_resp = ~s({"method":"isPrime","prime":true}\n)
    {:ok, next_resp} = :gen_tcp.recv(socket, 0, 10_000)
    assert next_resp == next_expected_resp
  end

  test "server returns malformed response for malformed input and closes the connection" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", @port, @socket_options)

    :gen_tcp.send(socket, JSON.encode!(%{"method" => "isNotPrime", "number" => 123}) <> "\n")
    {:ok, msg} = :gen_tcp.recv(socket, 0, 10_000)

    assert msg == "malformed\n"
    assert :gen_tcp.recv(socket, 0, 10_000) == {:error, :closed}
  end
end
