import struct
import os

def create_midi_file(filename, events):
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
    track_data = b''
    for delta, status, d1, d2 in events:
        if delta < 128:
            track_data += struct.pack('B', delta)
        elif delta < 16384:
            track_data += struct.pack('BB', (delta >> 7) | 0x80, delta & 0x7F)
        else:
            track_data += struct.pack('BBB', (delta >> 14) | 0x80, ((delta >> 7) & 0x7F) | 0x80, delta & 0x7F)
        track_data += struct.pack('BBB', status, d1, d2)
    track = b'MTrk' + struct.pack('>I', len(track_data)) + track_data
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, 'wb') as f:
        f.write(header + track)

# 案D: The Carbon Impact (精密・カチッ)
# 短いアタック音の連続
events_d = [
    (0, 0x90, 72, 110), (20, 0x90, 79, 100), (20, 0x90, 84, 115),
    (1200, 0x80, 72, 0), (0, 0x80, 79, 0), (0, 0x80, 84, 0),
    (0, 0xFF, 0x2F, 0)
]

# 案E: Champagne Ripple (高速上昇・光)
# 超高速な32分音符のアルペジオ
notes_e = [60, 64, 67, 71, 72, 76, 79, 83, 84, 91] # Cmaj7 系の広がり
events_e = []
for i, note in enumerate(notes_e):
    delta = 30 if i > 0 else 0 
    events_e.append((delta, 0x90, note, 80 + i*4))
events_e.append((2000, 0x80, notes_e[0], 0))
for i in range(1, len(notes_e)):
    events_e.append((0, 0x80, notes_e[i], 0))
events_e.append((0, 0xFF, 0x2F, 0))

# 案F: Zenith Horizon (ワイドな広がり)
# 中央から上下に広がる
events_f = [
    (0, 0x90, 72, 100), # Center C
    (60, 0x90, 67, 90), (0, 0x90, 76, 90), # Expand
    (60, 0x90, 60, 110), (0, 0x90, 84, 110), # Expand more
    (3000, 0x80, 72, 0), (0, 0x80, 67, 0), (0, 0x80, 76, 0), (0, 0x80, 60, 0), (0, 0x80, 84, 0),
    (0, 0xFF, 0x2F, 0)
]

if __name__ == "__main__":
    create_midi_file("assets/sounds/D_carbon_impact.mid", events_d)
    create_midi_file("assets/sounds/E_champagne_ripple.mid", events_e)
    create_midi_file("assets/sounds/F_zenith_horizon.mid", events_f)
    print("3 Premium Tech MIDI files generated.")
