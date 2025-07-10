# Test Seeds for UK LRT data
# Run with: MIX_ENV=test mix run priv/repo/seeds_test.exs

import Ecto.Query

# Sample families and types for realistic test data
families = ["Transport", "Railway", "Infrastructure", "Planning", "Environment"]
family_ii_options = ["Urban", "Rural", "Commercial", "Residential", "Mixed"]
statuses = ["✔ In force", "❌ Revoked / Repealed / Abolished", "⭕ Part Revocation / Repeal"]
types = ["Act", "Regulation", "Order", "Statutory Instrument", "Notice"]

# Generate 100 test records using direct SQL insertion
records = for i <- 1..100 do
  family = Enum.random(families)
  family_ii = Enum.random(family_ii_options)
  status = Enum.random(statuses)
  type_desc = Enum.random(types)
  year = Enum.random(1990..2024)
  
  %{
    id: Ecto.UUID.bingenerate(),
    name: "Test #{type_desc} #{i}",
    family: family,
    family_ii: family_ii,
    year: year,
    number: "TR#{String.pad_leading(to_string(i), 3, "0")}",
    live: status,
    type_desc: type_desc,
    md_description: "Test description for #{type_desc} #{i} relating to #{family} in #{family_ii} areas. This is sample data for testing purposes.",
    tags: Enum.take_random(["transport", "legal", "planning", "environment", "infrastructure"], Enum.random(1..3)),
    role: Enum.take_random(["primary", "secondary", "supporting", "reference"], Enum.random(1..2)),
    created_at: DateTime.utc_now()
  }
end

# Insert all records in a single operation
case Sertantai.Repo.insert_all("uk_lrt", records) do
  {count, _} ->
    IO.puts("Successfully created #{count} test UK LRT records!")
  error ->
    IO.puts("Error creating records: #{inspect(error)}")
end