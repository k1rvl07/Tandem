#!/usr/bin/env python3
"""Прикрепляет on_response-скрипт токена к запросам login/refresh в коллекции posting.

Запускается из dev.fish после `posting import tandem-backend/docs/swagger.json -o .posting`,
иначе переимпорт сотрёт доработки коллекции.
"""

import pathlib
import sys


SCRIPT_REF = "scripts/token_capture.py:capture_token"
MARKERS = {"/api/v1/auth/login", "/api/v1/auth/refresh"}


def main() -> int:
    collection = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".posting")
    patch = "\nscripts:\n  on_response: {0}\n".format(SCRIPT_REF)
    patched = 0
    for request_file in collection.glob("**/*.posting.yaml"):
        text = request_file.read_text(encoding="utf-8")
        if not any(marker in text for marker in MARKERS):
            continue
        if "scripts:" in text:
            continue
        request_file.write_text(text.rstrip() + patch, encoding="utf-8")
        patched += 1
    print(f"attach_capture: scripts.on_response добавлен в {patched} запроса(ов) коллекции {collection}")
    return 0


if __name__ == "__main__":
    sys.exit(main())