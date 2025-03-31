defmodule Response do
  defstruct status_code: nil,
            headers: %{},
            body: ""

  def format(%Response{status_code: status_code, body: body, headers: headers}) do
    body =
      case is_nil(body) do
        true -> ""
        false -> body
      end

    "HTTP/1.1 " <>
      "#{to_string(status_code)} #{status_reason(status_code)}\r\n" <>
      format_headers(headers) <>
      "\r\n\r\n" <>
      body
  end

  defp status_reason(code) do
    %{
      200 => "OK",
      201 => "Created",
      401 => "Unauthorized",
      403 => "Forbidden",
      404 => "Not Found",
      500 => "Internal Server Error"
    }[code]
  end

  defp format_headers(headers) do
    for({key, value} <- headers, do: "#{key}: #{value}\r")
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  def gzip(%Response{} = response) do
    new_body = :zlib.gzip(response.body)

    %Response{
      response
      | headers:
          response.headers
          |> Map.put("Content-Encoding", "gzip")
          |> Map.put("Content-Length", byte_size(new_body)),
        body: new_body
    }
  end
end
