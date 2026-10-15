#!/usr/bin/env python3
"""Place 16 isolated spoken cues on four equal beats per box side.

Input is the retained, unmodified ElevenLabs MP3. Only the gaps are retimed;
pitch and speaking speed are preserved. Requires ffmpeg on PATH.
"""
import array
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import wave

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'docs/audio/counting-source.mp3'
OUTPUT = ROOT / 'Flow/Resources/counting-cycle.wav'
MANIFEST = ROOT / 'docs/audio/counting-timing.json'
RATE = 24000
BEAT = 1.25  # Keep in sync with BreathingRhythm.beatDuration.
WORDS = ['inhale', 'two', 'three', 'four', 'hold', 'two', 'three', 'four',
         'exhale', 'two', 'three', 'four', 'hold', 'two', 'three', 'four']


def main():
    with tempfile.TemporaryDirectory(prefix='flow-counting-') as directory:
        decoded = Path(directory) / 'source.wav'
        subprocess.run(['ffmpeg', '-v', 'error', '-i', str(SOURCE), '-ar', str(RATE),
                        '-ac', '1', '-c:a', 'pcm_s16le', str(decoded)], check=True)
        with wave.open(str(decoded)) as f:
            data = array.array('h', f.readframes(f.getnframes()))
        result = subprocess.run(['ffmpeg', '-hide_banner', '-i', str(decoded), '-af',
            'silencedetect=noise=-42dB:d=0.24', '-f', 'null', '-'], capture_output=True,
            text=True, check=True)
    boundaries = re.findall(r'silence_(start|end): ([\d.]+)', result.stderr)
    spans, start = [], 0.0
    for kind, timestamp in boundaries:
        time = float(timestamp)
        if kind == 'start':
            if time > start + 0.08:
                spans.append((max(0, start - 0.025), min(len(data) / RATE, time + 0.045)))
        else:
            start = time
    if start < len(data) / RATE - 0.1 and (not boundaries or boundaries[-1][0] == 'end'):
        spans.append((max(0, start - 0.025), len(data) / RATE))
    if len(spans) != len(WORDS):
        raise ValueError(f'Expected 16 isolated cues, found {len(spans)}: {spans}. Inspect the source before editing cuts.')
    frames = round(BEAT * RATE)
    output = array.array('h', [0]) * (16 * frames)
    manifest = []
    for index, (word, (start, end)) in enumerate(zip(WORDS, spans)):
        clip = data[round(start * RATE):round(end * RATE)]
        if len(clip) > frames - 480:
            raise ValueError(f'{word} at {start:.3f} lasts {len(clip) / RATE:.3f}s; do not truncate or speed up speech.')
        # Five-millisecond fades prevent editing clicks; keep natural delivery intact.
        fade = 120
        for i in range(min(fade, len(clip))):
            clip[i] = round(clip[i] * i / fade)
            clip[-i - 1] = round(clip[-i - 1] * i / fade)
        target = index * frames + 240  # A consistent 10 ms attack lead.
        output[target:target + len(clip)] = clip
        manifest.append({'word': word, 'source_start': start, 'source_end': end,
                         'beat_start': index * BEAT, 'audio_start': target / RATE})
    with wave.open(str(OUTPUT), 'wb') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(output.tobytes())
    MANIFEST.write_text(json.dumps({'voice': 'Brian', 'model': 'Eleven v4',
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'output_sha256': hashlib.sha256(OUTPUT.read_bytes()).hexdigest(),
        'beat_seconds': BEAT, 'cycle_seconds': len(output) / RATE, 'cues': manifest}, indent=2) + '\n')
    print(f'Prepared {len(WORDS)} cues, {len(output) / RATE:.3f}s, peak {max(map(abs, output))/32768:.3f}')


if __name__ == '__main__':
    main()
