"""Kokoro-82M TTS server for Claude Code post-hook.

Keeps the model warm in memory. Single endpoint: POST /speak.
Generates WAV audio and returns the file path for playback.
"""

import logging
import os
import sys

import soundfile as sf
from flask import Flask, jsonify, request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    stream=sys.stdout,
)
log = logging.getLogger("tts-server")

WAV_DIR = "/tmp/claude-tts"
WAV_PATH = os.path.join(WAV_DIR, "speech.wav")
SAMPLE_RATE = 24000

DEFAULT_VOICE = os.environ.get("KOKORO_VOICE", "am_puck")

# Kokoro lang codes: a = American English
# Note: German not supported by Kokoro-82M, handled by macOS `say` in the hook
LANG_CODES = {
    "en": "a",
}

app = Flask(__name__)

# --- Model loading at startup ---

pipelines: dict = {}


def load_model():
    """Load Kokoro pipelines for EN and DE. Called once at startup."""
    from kokoro import KPipeline

    log.info("Loading Kokoro pipelines...")

    for lang, code in LANG_CODES.items():
        try:
            pipelines[lang] = KPipeline(lang_code=code)
            log.info("Loaded pipeline: %s (lang_code=%s)", lang, code)
        except Exception:
            log.exception("Failed to load pipeline for %s", lang)

    if not pipelines:
        log.error("No pipelines loaded. Server will return errors.")
    else:
        log.info("Model ready. Listening on 127.0.0.1:58732")


@app.route("/health", methods=["GET"])
def health():
    return jsonify(status="ok", languages=list(pipelines.keys()), default_voice=DEFAULT_VOICE)


@app.route("/voice", methods=["POST"])
def set_voice():
    """Change the default voice at runtime. POST {"voice": "am_adam"}"""
    global DEFAULT_VOICE
    data = request.get_json(silent=True)
    if not data or "voice" not in data:
        return jsonify(error="missing 'voice' field", current=DEFAULT_VOICE), 400
    DEFAULT_VOICE = data["voice"]
    log.info("Voice changed to: %s", DEFAULT_VOICE)
    return jsonify(voice=DEFAULT_VOICE)


@app.route("/speak", methods=["POST"])
def speak():
    data = request.get_json(silent=True)
    if not data or "text" not in data:
        return jsonify(error="missing 'text' field"), 400

    text = data["text"].strip()
    if not text:
        return jsonify(error="empty text"), 400

    lang = data.get("lang", "en")
    if lang not in pipelines:
        # Fall back to English if requested language not available
        lang = "en"
        if lang not in pipelines:
            return jsonify(error="no pipelines available"), 503

    pipe = pipelines[lang]
    voice = data.get("voice", DEFAULT_VOICE)

    try:
        results = list(pipe(text, voice=voice, speed=1.0))
        if not results:
            return jsonify(error="no audio generated"), 500

        # Concatenate audio chunks
        import torch

        audio = torch.cat([r.audio for r in results])
        audio_np = audio.cpu().numpy()

        os.makedirs(WAV_DIR, exist_ok=True)
        sf.write(WAV_PATH, audio_np, SAMPLE_RATE)

        return jsonify(wav=WAV_PATH)

    except Exception:
        log.exception("TTS generation failed")
        return jsonify(error="generation failed"), 500


if __name__ == "__main__":
    load_model()
    app.run(host="127.0.0.1", port=58732, threaded=False)
