# Sync Tool Integration Guide

This document describes how external sync tools can integrate with Sertantai to access user-selected records.

## Overview

Sertantai provides persistent record selection functionality where users can select UK LRT records through the web interface at `/records`. These selections are:

- **Persistent across sessions** - selections survive browser refreshes and new sessions
- **User-specific** - each authenticated user has their own set of selected records
- **Available via API** - sync tools can access selections through REST endpoints

## Authentication

All sync API endpoints require authentication. Use the same authentication mechanism as the main application (session-based or API tokens).

## API Endpoints

### Get Selected Record IDs

```
GET /api/sync/selected_ids
```

Returns a JSON array of selected record IDs for the authenticated user.

**Response:**
```json
{
  "selected_ids": ["record-id-1", "record-id-2", "record-id-3"],
  "count": 3
}
```

### Get Selected Records (Full Data)

```
GET /api/sync/selected_records
```

Returns complete record data for all selected records.

**Response:**
```json
{
  "records": [
    {
      "id": "record-id-1",
      "name": "Record Name",
      "family": "Transport",
      "family_ii": "Aviation",
      "year": 2023,
      "number": "TR001",
      "status": "✔ In force",
      "type_description": "Regulation",
      "description": "Description of the record",
      "tags": [],
      "role": []
    }
  ],
  "count": 1,
  "selected_at": "2024-01-15T10:30:00Z"
}
```

### Export Selected Records

```
GET /api/sync/export/{format}
```

Where `{format}` is either `csv` or `json`.

Returns the selected records in the specified format as a downloadable file.

**CSV Response:** Returns CSV file with headers
**JSON Response:** Returns JSON file with record array

## Programming Interface

For direct programmatic access from Elixir code:

```elixir
# Get selected record IDs for a user
selected_ids = SertantaiWeb.RecordSelectionLive.get_user_selections(user_id)

# Get full record data for selected records
{:ok, records} = SertantaiWeb.RecordSelectionLive.get_user_selected_records(user_id)

# Direct access to UserSelections GenServer
Sertantai.UserSelections.get_selections(user_id)
Sertantai.UserSelections.store_selections(user_id, [record_ids])
Sertantai.UserSelections.clear_selections(user_id)
```

## Implementation Details

### Session Persistence

- Selections are stored in an ETS table managed by the `Sertantai.UserSelections` GenServer
- Data persists across application restarts (though ETS is in-memory)
- Each user's selections are keyed by their user ID
- Selections include timestamps for potential cleanup/expiry

### Performance

- ETS provides fast O(1) access to user selections
- Record data is fetched on-demand from the database
- Export functionality uses efficient streaming for large datasets

### Error Handling

All API endpoints return appropriate HTTP status codes:

- `200` - Success
- `400` - Bad request (invalid format, no selections)
- `401` - Unauthorized (authentication required)
- `500` - Internal server error

## Integration Examples

### Curl Example

```bash
# Get selected IDs
curl -X GET "https://your-sertantai-instance.com/api/sync/selected_ids" \
  -H "Authorization: Bearer your-auth-token"

# Export as CSV
curl -X GET "https://your-sertantai-instance.com/api/sync/export/csv" \
  -H "Authorization: Bearer your-auth-token" \
  -o "selected_records.csv"
```

### Python Example

```python
import requests

# Configure authentication
headers = {"Authorization": "Bearer your-auth-token"}
base_url = "https://your-sertantai-instance.com/api/sync"

# Get selected record IDs
response = requests.get(f"{base_url}/selected_ids", headers=headers)
selected_data = response.json()
print(f"User has {selected_data['count']} records selected")

# Get full record data
response = requests.get(f"{base_url}/selected_records", headers=headers)
records = response.json()["records"]

# Process records for your sync tool
for record in records:
    print(f"Processing {record['name']} ({record['family']})")
    # Your sync logic here
```

## User Workflow

1. User logs into Sertantai web interface
2. User navigates to `/records` page
3. User applies filters to find relevant records
4. User selects records using checkboxes
5. Selections are automatically persisted
6. External sync tool accesses selections via API
7. Sync tool processes/syncs the selected records to external systems

## Notes

- Selections persist until explicitly cleared by the user or programmatically
- The system supports up to 1000 selected records per user (configurable)
- Record selection state is real-time - changes in the UI are immediately available via API
- For high-frequency sync scenarios, consider caching and polling strategies