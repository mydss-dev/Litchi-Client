from pathlib import Path

path = Path('lib/features/account/account_page.dart')
text = path.read_text()
needle = "      if (code.isEmpty)\n        setState("
start = text.find(needle)
if start < 0:
    raise SystemExit('account center lint target not found')
text = text[:start] + text[start:].replace(
    needle,
    "      if (code.isEmpty) {\n        setState(",
    1,
)
return_pos = text.find("\n      return;", start)
if return_pos < 0:
    raise SystemExit('account center lint return not found')
text = text[:return_pos] + "\n      }" + text[return_pos:]
path.write_text(text)
