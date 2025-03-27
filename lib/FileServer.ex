defmodule FileServer do
  def serve(file) do
    %{"--directory" => file_dir} = parse_args(System.argv())

    {:ok, content} = File.read("#{file_dir}#{file}")
    content
  end

  defp parse_args(args),
    do: args |> Enum.chunk_every(2) |> Enum.into(%{}, fn [flag, value] -> {flag, value} end)
end
