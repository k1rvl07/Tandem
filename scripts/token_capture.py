"""on_response-скрипт posting: сохраняет access-токен из ответа.

Подключается к запросам «Вход по логину и паролю» и «Обновление access-токена»
(см. scripts/attach_capture.py). После успешного ответа кладёт токен
в сессионную переменную BEARERAUTH_BEARER_TOKEN, которую используют
остальные защищённые запросы коллекции.
"""


def capture_token(response, posting):
    try:
        payload = response.json()
    except Exception:
        return
    if not isinstance(payload, dict):
        return
    token = payload.get("token")
    if token:
        posting.set_variable("BEARERAUTH_BEARER_TOKEN", token)
        posting.notify("access-токен сохранён")