import Ash.Query

# Test basic read
IO.puts("Testing basic read...")
query = Sertantai.UkLrt |> Ash.Query.limit(3)
result = Ash.read(query, domain: Sertantai.Domain)
IO.inspect(result, label: "Read result")

# Test distinct families
IO.puts("Testing distinct families...")
families_query = Sertantai.UkLrt |> Ash.Query.for_read(:distinct_families)
families_result = Ash.read(families_query, domain: Sertantai.Domain)
IO.inspect(families_result, label: "Distinct families")

# Test distinct family_ii
IO.puts("Testing distinct family_ii...")
family_ii_query = Sertantai.UkLrt |> Ash.Query.for_read(:distinct_family_ii)
family_ii_result = Ash.read(family_ii_query, domain: Sertantai.Domain)
IO.inspect(family_ii_result, label: "Distinct family_ii")