import server as tts_server


def _reset_state() -> None:
    tts_server.DEFAULT_VOICE = "am_puck"
    tts_server.ACTIVE_MODEL = "kokoro"


def test_list_voices_returns_supported_kokoro_voices():
    _reset_state()
    client = tts_server.app.test_client()

    response = client.get("/voices")

    assert response.status_code == 200
    data = response.get_json()
    assert data["model"] == "kokoro"
    assert data["current_voice"] == "am_puck"
    assert "am_adam" in data["voices"]
    assert len(data["voices"]) >= 16


def test_set_voice_updates_default_voice_for_valid_voice():
    _reset_state()
    client = tts_server.app.test_client()

    response = client.post("/voice", json={"voice": "af_bella"})

    assert response.status_code == 200
    data = response.get_json()
    assert data["voice"] == "af_bella"
    assert tts_server.DEFAULT_VOICE == "af_bella"


def test_set_voice_rejects_unsupported_voice_with_actionable_error():
    _reset_state()
    client = tts_server.app.test_client()

    response = client.post("/voice", json={"voice": "not_real"})

    assert response.status_code == 400
    data = response.get_json()
    assert data["error"] == "unsupported voice"
    assert "not_real" in data["message"]
    assert "am_puck" in data["available_voices"]
    assert data["current"] == "am_puck"
