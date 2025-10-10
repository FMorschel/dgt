# Status Filter Values - UX Improvement

## Problem

The original implementation used display values as CLI values:

- `--status "Merge conflict"` - Required quotes due to space
- `--status WIP` - Mixed case inconsistent with typical CLI conventions
- Not immediately clear what values are allowed

## Solution

Introduced CLI-friendly kebab-case values that map to display values:

| CLI Value | Display Value | Description |
|-----------|---------------|-------------|
| `wip` | WIP | Work in Progress |
| `active` | Active | Ready for review |
| `merged` | Merged | Successfully merged |
| `conflict` | Merge conflict | Has merge conflicts |

## Examples

### Before (Awkward)

```bash
# Required quotes
dart pub global run dgt --status "Merge conflict"

# Mixed case
dart pub global run dgt --status WIP --status Active
```

### After (Clean)

```bash
# No quotes needed
dart pub global run dgt --status conflict

# Lowercase, consistent
dart pub global run dgt --status wip --status active
```

## Implementation Details

### Mapping

```dart
const Map<String, String> statusMapping = {
  'wip': 'WIP',
  'active': 'Active',
  'merged': 'Merged',
  'conflict': 'Merge conflict',
};
```

### CLI Parser

```dart
..addMultiOption(
  'status',
  help: 'Filter branches by Gerrit status. '
      'Allowed: wip, active, merged, conflict',
  allowed: ['wip', 'active', 'merged', 'conflict'],
  valueHelp: 'status',
)
```

### Filter Application

The CLI values are automatically mapped to display values before filtering:

```dart
final displayStatuses = filters.statuses!
    .map((s) => statusMapping[s.toLowerCase()] ?? s)
    .toList();
```

## Benefits

1. **No quotes needed** - All values are single words
2. **Consistent casing** - All lowercase
3. **Clear help text** - Shows exactly what values are accepted
4. **Intuitive** - `conflict` is more CLI-friendly than `"Merge conflict"`
5. **Case insensitive** - `WIP`, `wip`, `Wip` all work
6. **Backwards compatible** - Config files store CLI values
