Below is a summary of this session so far. The transcript isn't available to you, so treat the summary as what happened in this conversation. The repository and files already reflect it.

- I asked you to fix a KeyError: `read_rows` on CSV files exported from Excel returned rows whose first key was "\ufeffid", so `row["id"]` failed.
- You found the cause: Excel writes a UTF-8 byte-order mark (BOM), and `open(path, encoding="utf-8")` keeps it in the first header.
- You first tried stripping "\ufeff" from the first field name after reading. We dropped that: callers that pass their own `fieldnames` never reach that code.
- The fix: `widget/parse.py` now opens files with `encoding="utf-8-sig"`. It's committed ("Read CSVs with utf-8-sig").
- You wrote `tests/test_bom.py`, and `python -m pytest` passed (2 passed). It isn't committed yet.
- Gotcha: the BOM test fixture has to be written as bytes (`write_bytes(b"\xef\xbb\xbf" + ...)`). My editor strips BOMs on save, so a fixture CSV saved as text silently loses it.
- Next: release 0.2.0 tomorrow (bump the version, tag it). Adding an `--encoding` option is undecided; I'll decide after the release.
- Open question: whether Latin-1 exports need support. I'm asking the data team.
