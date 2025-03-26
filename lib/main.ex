defmodule Server do
  use Application

  def start(_type, _args) do
    Supervisor.start_link([{Task, fn -> Server.listen() end}], strategy: :one_for_one)
  end

  def listen() do
    # You can use print statements as follows for debugging, they'll be visible when running tests.
    IO.puts("Logs from your program will appear here!")

    # Uncomment this block to pass the first stage
    #
    # Since the tester restarts your program quite often, setting SO_REUSEADDR
    # ensures that we don't run into 'Address already in use' errors
    {:ok, socket} = :gen_tcp.listen(4221, [:binary, active: false, reuseaddr: true])

    listen_loop(socket)
  end

  def listen_loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, request} = :gen_tcp.recv(client, 0)

    response = handle_request(request)
    IO.puts("\nReceived request: #{request}")

    :gen_tcp.send(client, response)
    :gen_tcp.close(client)

    listen_loop(socket)
  end

  defp handle_request(request) do
    request
    |> parse
    |> format_response
  end

  defp parse(request) do
    [method, path, _] = request |> String.split("\r\n") |> Enum.at(0) |> String.split(" ")
    %{method: method, path: path}
  end

  defp format_response(%{ method: "GET", path: "/" }) do
    "HTTP/1.1 200 OK\r\n\r\n"
  end
  defp format_response(_conv) do
    "HTTP/1.1 404 Not Found\r\n\r\n"
  end
end

defmodule CLI do
  def main(_args) do
    # Start the Server application
    {:ok, _pid} = Application.ensure_all_started(:codecrafters_http_server)

    # Run forever
    Process.sleep(:infinity)
  end
end
