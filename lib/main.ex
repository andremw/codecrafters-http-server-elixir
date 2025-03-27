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
    spawn(fn ->
      {:ok, client} = :gen_tcp.accept(socket)

      {:ok, request} = :gen_tcp.recv(client, 0)

      response = handle_request(request)
      # IO.puts("\nReceived request: \n#{request}")

      :gen_tcp.send(client, response)
      :gen_tcp.close(client)
    end)

    listen_loop(socket)
  end

  defp handle_request(request) do
    request
    |> parse
    |> format_response
  end

  defp parse(request) do
    [top, _] = request |> String.split("\r\n\r\n")
    [request_line | headers_line] = top |> String.split("\r\n")
    [method, path, _] = request_line |> String.split(" ")
    # IO.puts("headers_line:\n")
    # IO.inspect(headers_line)
    headers =
      headers_line
      |> Enum.reduce(%{}, fn header_line, acc ->
        [key, value] = header_line |> String.split(": ")
        Map.put(acc, key, value)
      end)

    # IO.puts("headers: ")
    # IO.inspect(headers)
    %{method: method, path: path, headers: headers}
  end

  defp format_response(%{method: "GET", path: "/"}) do
    "HTTP/1.1 200 OK\r\n\r\n"
  end

  defp format_response(%{method: "GET", path: "/echo/" <> str}) do
    "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{byte_size(str)}\r\n\r\n#{str}"
  end

  defp format_response(%{method: "GET", path: "/user-agent", headers: %{"User-Agent" => ua}}) do
    "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{byte_size(ua)}\r\n\r\n#{ua}"
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
