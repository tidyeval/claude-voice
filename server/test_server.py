import server as tts_server


def _reset_state() -> None:
    tts_server.DEFAULT_VOICE = "am_puck"
    tts_server.pipelines.clear()


def test_health_reports_loaded_languages_and_default_voice():
    _reset_state()
    tts_server.pipelines["en"] = object()
    client = tts_server.app.test_client()

    response = client.get("/health")

    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["languages"] == ["en"]
    assert data["default_voice"] == "am_puck"


def test_set_voice_updates_default_voice():
    _reset_state()
    client = tts_server.app.test_client()

    response = client.post("/voice", json={"voice": "af_bella"})

    assert response.status_code == 200
    assert response.get_json() == {"voice": "af_bella"}
    assert tts_server.DEFAULT_VOICE == "af_bella"


def test_speak_returns_service_unavailable_without_loaded_pipeline():
    _reset_state()
    client = tts_server.app.test_client()

    response = client.post("/speak", json={"text": "Hello"})

    assert response.status_code == 503
    assert response.get_json() == {"error": "no pipelines available"}
