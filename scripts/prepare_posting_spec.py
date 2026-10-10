#!/usr/bin/env python3
"""Готовит swagger.json (swag) к импорту в posting.

posting требует валидный URL в externalDocs, а swag генерирует пустой
externalDocs {description:"", url:""}. Скрипт вычищает проблемные поля
и пишет очищенную спеку рядом, откуда dev.fish делает `posting import`.
"""

import json
import sys
import urllib.parse
from pathlib import Path


def clean(spec: dict) -> None:
    external = spec.get("externalDocs")
    if isinstance(external, dict):
        url = external.get("url")
        parsed = urllib.parse.urlsplit(url or "")
        if parsed.scheme not in ("http", "https") or not parsed.netloc:
            spec.pop("externalDocs", None)

    swag_file_types(spec)

    schemes = spec.get("components", {}).get("securitySchemes")
    if isinstance(schemes, dict):
        for scheme in schemes.values():
            if (
                isinstance(scheme, dict)
                and scheme.get("type") == "apiKey"
                and scheme.get("name") == "Authorization"
            ):
                # swag описывает Bearer-токен как apiKey-заголовок; posting
                # понимает только http/bearer и тогда подставляет
                # <ИМЯ>_BEARER_TOKEN (BEARERAUTH_BEARER_TOKEN).
                scheme.clear()
                scheme.update({"type": "http", "scheme": "bearer"})


def swag_file_types(node) -> None:
    """swag генерит `type: "file"` для загрузок файлов — это не OpenAPI.

    posting на это ругается; заменяем на стандартное `type: string, format: binary`.
    """
    if isinstance(node, dict):
        for key, value in list(node.items()):
            if key == "type" and value == "file":
                node["type"] = "string"
                node["format"] = "binary"
            else:
                swag_file_types(value)
    elif isinstance(node, list):
        for item in node:
            swag_file_types(item)


def main() -> int:
    source = Path(sys.argv[1] if len(sys.argv) > 1 else "tandem-backend/docs/swagger.json")
    target = Path(sys.argv[2] if len(sys.argv) > 2 else ".posting/swagger.import.json")
    spec = json.loads(source.read_text(encoding="utf-8"))
    clean(spec)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(spec), encoding="utf-8")
    print(f"prepare_posting_spec: {target} готов")
    return 0


if __name__ == "__main__":
    sys.exit(main())