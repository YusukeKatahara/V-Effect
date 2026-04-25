import struct
import os

def create_midi(filename):
    # MIDI header (MThd)
    header = b'MThd' + struct.pack('>IHHH', 6, 0, 1, 480)
    
    # MIDI events (delta_time, status, data1, data2)
    # C Major Triad: C5(60), E5(64), G5(67), C6(72)
    events = [
        (0, 0x90, 60, 100), (0, 0x90, 64, 100), (0, 0x90, 67, 100), (0, 0x90, 72, 100),
        (960, 0x80, 60, 0), (0, 0x80, 64, 0), (0, 0x80, 67, 0), (0, 0x80, 72, 0),
        (0, 0xFF, 0x2F, 0)
    ]
    
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
    print(f"MIDI file created at: {os.path.abspath(filename)}")

if __name__ == "__main__":
    create_midi("assets/sounds/success.mid")
