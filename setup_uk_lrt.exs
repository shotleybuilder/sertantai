# Create the uk_lrt table with sample data for testing
create_table_sql = """
CREATE TABLE uk_lrt (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family VARCHAR(255) NOT NULL,
  family_ii VARCHAR(255),
  name VARCHAR(255),
  description TEXT,
  metadata JSONB,
  inserted_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
"""

# Insert sample data
insert_data_sql = """
INSERT INTO uk_lrt (family, family_ii, name, description, metadata) VALUES
('Transport', 'Rail', 'London Underground', 'Metro system in London', '{"type": "metro", "lines": 11}'),
('Transport', 'Bus', 'Red Double Decker', 'Iconic London bus', '{"type": "bus", "capacity": 87}'),
('Transport', 'Rail', 'Overground', 'London Overground network', '{"type": "rail", "stations": 112}'),
('Logistics', 'Freight', 'Container Transport', 'Port to warehouse logistics', '{"type": "freight", "containers": 1000}'),
('Logistics', 'Delivery', 'Last Mile', 'Final delivery to customer', '{"type": "delivery", "radius": 50}'),
('Aviation', 'Commercial', 'Heathrow Routes', 'International flights', '{"type": "aviation", "runways": 2}'),
('Aviation', 'Cargo', 'Freight Airways', 'Cargo transportation', '{"type": "cargo", "capacity": 5000}'),
('Maritime', 'Passenger', 'Thames Clipper', 'River transport service', '{"type": "river", "stops": 23}'),
('Maritime', 'Cargo', 'Port Operations', 'Container ship operations', '{"type": "port", "berths": 8}'),
('Transport', 'Taxi', 'Black Cab', 'Traditional London taxi', '{"type": "taxi", "licensed": true}');
"""

IO.puts("Creating uk_lrt table...")
result1 = Ecto.Adapters.SQL.query(Sertantai.Repo, create_table_sql, [])
IO.inspect(result1, label: "Create table result")

IO.puts("Inserting sample data...")
result2 = Ecto.Adapters.SQL.query(Sertantai.Repo, insert_data_sql, [])
IO.inspect(result2, label: "Insert data result")

IO.puts("Setup complete!")