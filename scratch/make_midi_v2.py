import struct
import os

def create_midi(filename):
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
    
    # より豪華な和音とアルペジオ
    # C5, E5, G5, C6, G6, C7
    notes = [60, 64, 67, 72, 79, 84]
    
    events = []
    # Note On (少しずつずらして優雅に)
    for i, note in enumerate(notes):
        delta = 80 if i > 0 else 0 
        events.append((delta, 0x90, note, 80 + i*8)) 
        
    # Note Off (4拍以上しっかり伸ばす: 2500 ticks)
    events.append((2500, 0x80, notes[0], 0))
    for i in range(1, len(notes)):
        events.append((0, 0x80, notes[i], 0))
        
    events.append((0, 0xFF, 0x2F, 0))
    
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
    print(f"MIDI created: {os.path.abspath(filename)}")

if __name__ == "__main__":
    create_midi("assets/sounds/success2.mid")
