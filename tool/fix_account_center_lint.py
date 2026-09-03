from pathlib import Path

path = Path('lib/features/account/account_page.dart')
text = path.read_text()
old = """    if (code.isEmpty || _submitting) {\n      if (code.isEmpty)\n        setState(\n          () => _error = _accountText(\n"""
new = """    if (code.isEmpty || _submitting) {\n      if (code.isEmpty) {\n        setState(\n          () => _error = _accountText(\n"""
if old not in text:
    raise SystemExit('account center lint target not found')
text = text.replace(old, new, 1)
old_tail = """              en: 'Enter a redemption code',\n            ),\n        );\n      return;\n"""
new_tail = """              en: 'Enter a redemption code',\n            ),\n        );\n      }\n      return;\n"""
if old_tail not in text:
    raise SystemExit('account center lint tail not found')
path.write_text(text.replace(old_tail, new_tail, 1))
