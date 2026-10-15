from widget.parse import read_rows


def test_reads_rows(tmp_path):
    p = tmp_path / "a.csv"
    p.write_text("id,name\n1,a\n")
    assert read_rows(p) == [{"id": "1", "name": "a"}]
