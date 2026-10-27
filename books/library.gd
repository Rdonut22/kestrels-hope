class_name Library

## The books on the lounge shelf. Each is a public-domain Project Gutenberg
## plain-text file in res://books/; the Gutenberg header and footer are
## stripped and the hard-wrapped lines rejoined when it's opened.

const BOOKS := [
	{"id": "time_machine", "title": "The Time Machine", "author": "H. G. Wells", "year": "1895",
		"color": Color(0.15, 0.27, 0.31), "file": "res://books/the_time_machine.txt"},
	{"id": "secret_garden", "title": "The Secret Garden", "author": "Frances Hodgson Burnett", "year": "1911",
		"color": Color(0.25, 0.36, 0.21), "file": "res://books/the_secret_garden.txt"},
]
const BOOKMARKS := "user://bookmarks.cfg"


static func find(id: String) -> Dictionary:
	for book: Dictionary in BOOKS:
		if book.id == id:
			return book
	return {}


static func has_pages(book: Dictionary) -> bool:
	return FileAccess.file_exists(book.file)


## The book as BBCode for a RichTextLabel: indented paragraphs, centred bold
## chapter headings, _underscored_ words in italics.
static func load_bbcode(book: Dictionary) -> String:
	var raw := FileAccess.get_file_as_string(book.file).replace("\r", "")
	var start := raw.find("*** START OF")
	if start != -1:
		raw = raw.substr(raw.find("\n", start) + 1)
	var end := raw.find("*** END OF")
	if end != -1:
		raw = raw.substr(0, end)
	var out := PackedStringArray()
	var italic := RegEx.create_from_string("_([^_]+)_")
	for para in raw.split("\n\n"):
		var lines := PackedStringArray()
		for line in para.split("\n"):
			if line.strip_edges() != "":
				lines.append(line.strip_edges())
		if lines.is_empty():
			continue
		var text := " ".join(lines).replace("[", "[lb]")
		text = italic.sub(text, "[i]$1[/i]", true)
		if _is_heading(lines):
			out.append("\n[center][b]%s[/b][/center]\n" % text)
		else:
			out.append("      " + text)
	return "\n".join(out).strip_edges()


# Chapter titles: short paragraphs in all caps, or starting with a roman
# numeral line ("IV." / "CHAPTER IV") with an optional title under it.
static func _is_heading(lines: PackedStringArray) -> bool:
	if lines.size() > 2:
		return false
	var text := " ".join(lines)
	if text.length() > 60:
		return false
	var letters := text.to_upper() != text.to_lower()
	var numeral := RegEx.create_from_string("^(CHAPTER )?[IVXLC]+\\.?$").search(lines[0]) != null
	return (letters and text == text.to_upper()) or numeral


static func bookmark(id: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(BOOKMARKS)
	return cfg.get_value("pages", id, 0)


static func set_bookmark(id: String, page: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(BOOKMARKS)
	cfg.set_value("pages", id, page)
	cfg.save(BOOKMARKS)
