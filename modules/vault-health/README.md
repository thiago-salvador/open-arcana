# Vault Health Module

Automated test suite for measuring vault quality. Runs 5 test categories and produces a composite score, inspired by Karpathy's autoresearch methodology: fixed metrics, reproducible, scriptable.

## Tests

| Test | Weight | What it checks |
|------|--------|----------------|
| Test 1: Retrieval Accuracy | 30% | Can the concept-index and aliases resolve known queries? |
| Test 2: Data Integrity | 25% | People notes have complete frontmatter, quality summaries, wikilinks |
| Test 3: Index Consistency | 20% | Every folder has index.md, no orphan notes, no phantom links |
| Test 4: Freshness | 15% | Hot-cache links resolve, concept-index covers all people/projects, daily note exists |
| Test 5: Tasks Health | 10% | Scheduled tasks left evidence in recent daily notes, config/hooks exist |

## Usage

```bash
# Run all tests
bash vault-test.sh

# Run a specific test
bash vault-test.sh test1
bash vault-test.sh test3

# Set vault path via environment
VAULT=/path/to/vault bash vault-test.sh
```

## Setup

1. Copy `vault-test.sh` to your vault root (or keep it outside and set `VAULT` env var).
2. Edit the `VAULT` variable or set `{{VAULT_PATH}}` to your actual vault path.
3. **Customize the test data:**
   - Test 1: Add your concept-index queries and alias queries to the arrays
   - Test 2: Update role keywords to match your vault's people notes
   - Test 3: Update folder names and subdirectory lists to match your vault structure
   - Test 4: Add your expected hot-cache Tier 1 entries
   - Test 5: Add task markers for your scheduled tasks
4. The people folder defaults to `70-People`. Change the `PESSOAS` variable if your vault uses a different name.

## Output

The script produces:
- Per-test pass/fail details with color-coded output
- A percentage score for each test
- A weighted composite VAULT SCORE

Example output:
```
==================================
  VAULT TEST SUITE v2
  2026-04-05 14:30
==================================

=== Test 1: Retrieval Accuracy ===
  Result: 45/50 passed (90.0%)

=== Test 2: Data Integrity (People) ===
  MISSING: John Doe -- field 'last_interaction'
  Result: 98/100 passed (98.0%)

...

==================================
  Test 1 (Retrieval):    90.0%
  Test 2 (Integrity):    98.0%
  Test 3 (Consistency):  95.0%
  Test 4 (Freshness):    88.0%
  Test 5 (Tasks):        80.0%
==================================
  VAULT SCORE: 92.2
==================================
```

## Extending

To add new tests:
1. Create a new `testN_name()` function following the same pattern
2. Add it to the main execution block
3. Update the composite score weights (must sum to 1.0)
4. Update the summary output
