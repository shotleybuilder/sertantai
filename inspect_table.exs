# Get all columns for uk_lrt table
case Ecto.Adapters.SQL.query(Sertantai.Repo, "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name = 'uk_lrt' ORDER BY ordinal_position", []) do
  {:ok, result} ->
    IO.puts("✅ Complete uk_lrt table structure:")
    result.rows 
    |> Enum.with_index(1) 
    |> Enum.each(fn {[name, type, nullable], idx} ->
      IO.puts("#{idx}. #{name} (#{type}) #{if nullable == "YES", do: "NULL", else: "NOT NULL"}")
    end)
  {:error, error} ->
    IO.inspect(error, label: "Error getting table structure")
end