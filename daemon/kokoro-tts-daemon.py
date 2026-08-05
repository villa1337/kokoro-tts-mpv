#!/usr/bin/env python3
"""Kokoro TTS daemon: stays loaded in memory, accepts text via Unix socket, plays audio."""
import os
import sys
import socket
import tempfile
import threading
import subprocess
import signal
import numpy as np
import soundfile as sf
from kokoro import KPipeline

SOCKET_PATH = "/tmp/kokoro-tts.sock"
VOICE = "af_heart"
SPEED = 1.1
SAMPLE_RATE = 24000

# Global state
pipeline = None
current_playback = None
lock = threading.Lock()


def init_pipeline():
    global pipeline
    print("🎙️  Loading Kokoro TTS model...", flush=True)
    pipeline = KPipeline(lang_code="a", repo_id="hexgrad/Kokoro-82M")
    print("✅ Kokoro ready. Listening on", SOCKET_PATH, flush=True)


def stop_playback():
    """Kill any currently playing audio."""
    global current_playback
    if current_playback and current_playback.poll() is None:
        current_playback.kill()
        current_playback = None


def speak(text):
    """Generate and play TTS for the given text."""
    global current_playback

    text = text.strip()
    if not text:
        return

    # Stop any ongoing speech
    stop_playback()

    # Generate audio
    chunks = []
    for _, _, audio in pipeline(text, voice=VOICE, speed=SPEED, split_pattern=r"\n+"):
        chunks.append(audio)

    if not chunks:
        return

    combined = np.concatenate(chunks)

    # Write temp WAV
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    sf.write(tmp.name, combined, SAMPLE_RATE)
    tmp.close()

    # Play via paplay (non-blocking)
    current_playback = subprocess.Popen(
        ["paplay", tmp.name],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    # Clean up temp file after playback finishes (in background)
    def cleanup():
        current_playback.wait()
        try:
            os.unlink(tmp.name)
        except OSError:
            pass

    threading.Thread(target=cleanup, daemon=True).start()


def handle_client(conn):
    """Handle a single client connection."""
    try:
        data = conn.recv(4096).decode("utf-8", errors="replace")
        if data.strip() == "STOP":
            stop_playback()
        elif data.strip() == "QUIT":
            stop_playback()
            if os.path.exists(SOCKET_PATH):
                os.unlink(SOCKET_PATH)
            os._exit(0)
        elif data.strip():
            with lock:
                speak(data)
    except Exception as e:
        print(f"Error: {e}", flush=True)
    finally:
        conn.close()


def main():
    # Clean up old socket
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)

    init_pipeline()

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(5)

    def shutdown(signum, frame):
        stop_playback()
        server.close()
        if os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    while True:
        conn, _ = server.accept()
        threading.Thread(target=handle_client, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
