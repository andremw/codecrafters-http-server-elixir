defmodule Server do
  use Application

  alias Response

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
    request = parse(request)

    request
    |> handle
    |> gzip_if_necessary(request.headers)
    |> Response.format()
  end

  defp gzip_if_necessary(response, %{"Accept-Encoding" => encodings}) do
    case String.contains?(encodings, "gzip") do
      false -> response
      true -> Response.gzip(response)
    end
  end

  defp gzip_if_necessary(response, _), do: response

  defp parse(request) do
    [top, body] = request |> String.split("\r\n\r\n")
    [request_line | headers_line] = top |> String.split("\r\n")
    [method, path, _] = request_line |> String.split(" ")
    headers = headers_line_to_map(headers_line)

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

  defp handle(%{method: "GET", path: "/"}) do
    %Response{status_code: 200, headers: %{}, body: nil}
  end

  defp handle(%{method: "GET", path: "/echo/" <> str}) do
    %Response{
      status_code: 200,
      headers: %{
        "Content-Type" => "text/plain",
        "Content-Length" => byte_size(str)
      },
      body: str
    }
  end

  defp handle(%{method: "GET", path: "/user-agent", headers: %{"User-Agent" => ua}}) do
    %Response{
      status_code: 200,
      headers: %{
        "Content-Type" => "text/plain",
        "Content-Length" => byte_size(ua)
      },
      body: ua
    }
  end

  ### /files
  defp handle(%{method: "GET", path: "/files/" <> filename}) do
    case FileServer.serve(filename) do
      {:ok, content} ->
        size = byte_size(content)

        %Response{
          status_code: 200,
          headers: %{
            "Content-Type" => "application/octet-stream",
            "Content-Length" => size
          },
          body: content
        }

      _ ->
        # returns 404
        %Response{
          status_code: 404,
          headers: %{},
          body: nil
        }
    end
  end

  defp handle(%{
         method: "POST",
         path: "/files/" <> filename,
         headers: %{"Content-Type" => "application/octet-stream", "Content-Length" => _size},
         body: content
       }) do
    FileServer.create(filename, content)
    %Response{status_code: 201, body: nil, headers: %{}}
  end

  defp handle(_conv) do
    %Response{status_code: 404, body: nil, headers: %{}}
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
