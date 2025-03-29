defmodule FileServer do
  def serve(file) do
    %{"--directory" => file_dir} = parse_args(System.argv())

    File.read("#{file_dir}#{file}")
  end

  def create(filename, content) do
    %{"--directory" => file_dir} = parse_args(System.argv())

    File.write("#{file_dir}/#{filename}", content)
  end

  defp parse_args(args),
    do: args |> Enum.chunk_every(2) |> Enum.into(%{}, fn [flag, value] -> {flag, value} end)
end
