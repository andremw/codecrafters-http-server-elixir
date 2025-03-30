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

    spawn(fn ->
      {:ok, request} = :gen_tcp.recv(client, 0)

      response = handle_request(request)
      IO.puts("\nReceived request: \n#{request}")

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
    [top, body] = request |> String.split("\r\n\r\n")
    [request_line | headers_line] = top |> String.split("\r\n")
    [method, path, _] = request_line |> String.split(" ")
    # IO.puts("headers_line:\n")
    # IO.inspect(headers_line)
    headers = headers_line_to_map(headers_line)

    # IO.puts("headers: ")
    # IO.inspect(headers)

    body = body |> String.split("\r\n")

    %{method: method, path: path, headers: headers, body: body}
  end

  defp headers_line_to_map(headers_line) do
    headers_line
    |> Enum.reduce(%{}, fn header_line, acc ->
      [key, value] = header_line |> String.split(": ")
      Map.put(acc, key, value)
    end)
  end

  defp format_response(%{method: "GET", path: "/"}) do
    "HTTP/1.1 200 OK\r\n\r\n"
  end

  defp format_response(%{method: "GET", path: "/echo/" <> str, headers: headers}) do
    {content_encoding, str} =
      case Map.get(headers, "Accept-Encoding") do
        encodings when not is_nil(encodings) ->
          case String.contains?(encodings, "gzip") do
            true -> {"\r\nContent-Encoding: gzip", str |> :zlib.gzip()}
            false -> {"", str}
          end

        _ ->
          {"", str}
      end

    "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{byte_size(str)}" <>
      content_encoding <>
      "\r\n\r\n#{str}"
  end

  defp format_response(%{method: "GET", path: "/user-agent", headers: %{"User-Agent" => ua}}) do
    "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: #{byte_size(ua)}\r\n\r\n#{ua}"
  end

  ### /files
  defp format_response(%{method: "GET", path: "/files/" <> filename}) do
    case FileServer.serve(filename) do
      {:ok, content} ->
        size = byte_size(content)

        "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: #{size}\r\n\r\n#{content}"

      _ ->
        # returns 404
        format_response({})
    end
  end

  defp format_response(%{
         method: "POST",
         path: "/files/" <> filename,
         headers: %{"Content-Type" => "application/octet-stream", "Content-Length" => _size},
         body: content
       }) do
    FileServer.create(filename, content)
    "HTTP/1.1 201 Created\r\n\r\n"
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
