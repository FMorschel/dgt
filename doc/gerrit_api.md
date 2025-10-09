<!-- markdownlint-disable MD040 -->
# Gerrit API Documentation

This document describes the Gerrit REST API endpoints used by DGT and the data formats involved.

## API Endpoints

DGT uses the Gerrit REST API to query change information. The tool supports two query methods:

### 1. Query by Change Number (Preferred)

**Endpoint:** `GET /changes/{change-number}?o=CURRENT_REVISION`

**Example:**

```
https://dart-review.googlesource.com/changes/389423?o=CURRENT_REVISION
```

**Parameters:**

- `{change-number}` - The Gerrit change/issue number (e.g., 389423)
- `o=CURRENT_REVISION` - Query option to include the current revision hash in the response

**Use Case:** This is the primary method used by DGT when the change number is available in the Git config (stored by Gerrit upload tools).

### 2. Query by Change-ID

**Endpoint:** `GET /changes/?q=change:{change-id}`

**Example:**

```
https://dart-review.googlesource.com/changes/?q=change:Iabc123def456...
```

**Parameters:**

- `q=change:{change-id}` - Query string to search for a specific Change-ID

**Use Case:** Used when only the Change-ID is available (extracted from commit messages).

### 3. Batch Query (Multiple Changes)

**Endpoint:** `GET /changes/?q={query1}&q={query2}&q={query3}...&o=CURRENT_REVISION`

**Example:**

```
https://dart-review.googlesource.com/changes/?q=389423&q=389424&q=389425&o=CURRENT_REVISION
```

**Parameters:**

- Multiple `q={change-number}` parameters (up to 10 per request)
- `o=CURRENT_REVISION` - Include current revision hashes

**Use Case:** DGT uses this for performance optimization when querying multiple branches. Batching reduces the number of HTTP round-trips significantly.

**Limitations:**

- Maximum 10 queries per request (Gerrit API limitation)
- Larger batches are automatically split into multiple requests

## XSSI Protection

All Gerrit JSON responses include an XSSI (Cross-Site Script Inclusion) protection prefix to prevent the response from being executed as JavaScript.

**Prefix:** `)]}'\n`

**Example Raw Response:**

```
)]}'
{"change_id": "Iabc123...", "status": "NEW", ...}
```

**Handling:**
The DGT tool automatically strips this prefix before parsing JSON:

```dart
if (jsonBody.startsWith(xssiPrefix)) {
  jsonBody = jsonBody.substring(xssiPrefix.length);
}
```

This security measure prevents malicious websites from including the Gerrit API response as a `<script>` tag and accessing the data.

## Response Format

### Single Change Response

```json
{
  "_number": 389423,
  "change_id": "Iabc123def456789...",
  "status": "NEW",
  "work_in_progress": false,
  "mergeable": true,
  "updated": "2025-10-07 14:30:45.000000000",
  "current_revision": "abc123def456...",
  "revisions": {
    "abc123def456...": {
      "_number": 3,
      "created": "2025-10-07 14:30:45.000000000"
    }
  }
}
```

### Batch Query Response

The batch query returns an array of arrays, where each inner array contains the results for one query:

```json
[
  [
    {
      "_number": 389423,
      "change_id": "Iabc123...",
      "status": "NEW",
      ...
    }
  ],
  [],
  [
    {
      "_number": 389425,
      "change_id": "Idef456...",
      "status": "MERGED",
      ...
    }
  ]
]
```

**Structure:**

- Outer array: One element per query
- Inner array: Contains 0 or 1 change objects (empty if not found)

## Key Fields

DGT extracts the following fields from the Gerrit API response:

| Field | Type | Description |
|-------|------|-------------|
| `_number` | integer | The change number (same as issue number) |
| `change_id` | string | The Change-ID (e.g., "Iabc123...") |
| `status` | string | Change status: "NEW", "MERGED", "ABANDONED" |
| `work_in_progress` | boolean | Whether the change is marked as WIP |
| `mergeable` | boolean | Whether the change can be merged without conflicts |
| `updated` | string | Last updated timestamp (ISO 8601 format) |
| `current_revision` | string | The current commit hash (SHA-1) |

## Status Mapping

DGT maps Gerrit API fields to user-friendly statuses:

| Gerrit Condition | DGT Status | Priority |
|-----------------|------------|----------|
| `status == "MERGED"` | **Merged** | 1 (Highest) |
| `mergeable == false` | **Merge conflict** | 2 |
| `work_in_progress == true` | **WIP** | 3 |
| `status == "NEW"` | **Active** | 4 (Default) |

**Priority Rules:**

- Priorities determine which status is shown when multiple conditions are true
- Higher priority (lower number) takes precedence
- Example: A change that is merged will show "Merged" even if it previously had merge conflicts

## Error Handling

### HTTP Status Codes

| Code | Meaning | DGT Handling |
|------|---------|--------------|
| 200 | Success | Parse and display change data |
| 404 | Not Found | Display "-" for Gerrit columns (branch not uploaded) |
| 429 | Rate Limited | Currently not handled (future enhancement) |
| 500 | Server Error | Log error, continue with other branches (partial success) |

### Partial Success

DGT is designed for partial success - if some Gerrit queries fail, it continues processing other branches and displays available data. Failed queries show "-" in the Gerrit columns.

## Performance Optimizations

### 1. Batch Queries

- Reduces N individual API calls to N/10 batch calls (with batches of 10)
- Significantly reduces network latency and total execution time

### 2. Isolate-based Processing

- Each batch query runs in a separate isolate (lightweight thread)
- Prevents blocking the main event loop
- Enables parallel execution of multiple batches

### 3. JSON Decoding in Isolates

- Large JSON responses are decoded in separate isolates
- Prevents UI freezing or CLI blocking during parsing

## Example Usage

### Individual Query (by change number)

```bash
curl "https://dart-review.googlesource.com/changes/389423?o=CURRENT_REVISION"
```

### Batch Query (multiple changes)

```bash
curl "https://dart-review.googlesource.com/changes/?q=389423&q=389424&o=CURRENT_REVISION"
```

### Query by Change-ID

```bash
curl "https://dart-review.googlesource.com/changes/?q=change:Iabc123def456..."
```

**Note:** All responses will include the `)]}'\n` prefix that must be stripped before JSON parsing.

## References

- [Gerrit REST API Documentation](https://gerrit-review.googlesource.com/Documentation/rest-api.html)
- [Gerrit Changes API](https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html)
- [XSSI Protection](https://gerrit-review.googlesource.com/Documentation/rest-api.html#output)
