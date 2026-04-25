import struct
import os

def create_midi_file(filename, events):
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
    track_data = b''
    for delta, status, d1, d2 in events:
        if delta < 128:
            track_data += struct.pack('B', delta)
        else:
            track_data += struct.pack('BB', (delta >> 7) | 0x80, delta & 0x7F)
        track_data += struct.pack('BBB', status, d1, d2)
    track = b'MTrk' + struct.pack('>I', len(track_data)) + track_data
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with open(filename, 'wb') as f:
        f.write(header + track)

# 案A: The Solid Base (低音・安定感)
# G3(43), C4(48), G4(55)
events_a = [
    (0, 0x90, 43, 110), (0, 0x90, 48, 105), (0, 0x90, 55, 100),
    (1920, 0x80, 43, 0), (0, 0x80, 48, 0), (0, 0x80, 55, 0),
    (0, 0xFF, 0x2F, 0)
]

# 案B: Pure Ascent (上昇・透明感)
# C5(60), G5(67), C6(72), E6(76), G6(79)
events_b = [
    (0, 0x90, 60, 80), (120, 0x90, 67, 85), (120, 0x90, 72, 90), (120, 0x90, 76, 95), (120, 0x90, 79, 100),
    (1920, 0x80, 60, 0), (0, 0x80, 67, 0), (0, 0x80, 72, 0), (0, 0x80, 76, 0), (0, 0x80, 79, 0),
    (0, 0xFF, 0x2F, 0)
]

# 案C: Gold Ripple (黄金・プレミアム)
# C5(60), E5(64), G5(67), B5(71), D6(74), G6(79)
events_c = [
    (0, 0x90, 60, 90), (60, 0x90, 64, 95), (60, 0x90, 67, 100), (60, 0x90, 71, 105), (60, 0x90, 74, 110), (60, 0x90, 79, 115),
    (2400, 0x80, 60, 0), (0, 0x80, 64, 0), (0, 0x80, 67, 0), (0, 0x80, 71, 0), (0, 0x80, 74, 0), (0, 0x80, 79, 0),
    (0, 0xFF, 0x2F, 0)
]

if __name__ == "__main__":
    create_midi_file("assets/sounds/A_solid_base.mid", events_a)
    create_midi_file("assets/sounds/B_pure_ascent.mid", events_b)
    create_midi_file("assets/sounds/C_gold_ripple.mid", events_c)
    print("3 Recommended MIDI files generated.")
