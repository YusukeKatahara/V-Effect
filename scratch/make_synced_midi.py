import mido
from mido import Message, MidiFile, MidiTrack, MetaMessage

def create_synced_midi(filename):
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    
    # 120 BPM (500,000 microseconds per beat)
    track.append(MetaMessage('set_tempo', tempo=500000))
    
    # MIDI Ticks per beat
    ticks_per_beat = mid.ticks_per_beat # Default is 480
    
    # Timing calculation:
    # 0.0s = 0 ticks
    # 1.2s = 2.4 beats = 2.4 * 480 = 1152 ticks (Peak/Impact)
    # 2.6s = 5.2 beats = 5.2 * 480 = 2496 ticks (Final End)
    
    peak_tick = 1152
    end_tick = 2496
    
    # --- PHASE 1: Ascending Arpeggio (0.0s to 1.2s) ---
    # Rising tension. 8 notes leading up to the impact.
    arpeggio_notes = [48, 52, 55, 60, 64, 67, 72, 76] # C3, E3, G3, C4, E4, G4, C5, E5
    step = peak_tick // len(arpeggio_notes)
    
    for i, note in enumerate(arpeggio_notes):
        # Velocity increases as it approaches the peak
        vel = 60 + (i * 8)
        track.append(Message('note_on', note=note, velocity=vel, time=0 if i == 0 else step))
        # We'll keep them ringing for a bit of overlap, but they should release near the peak
        track.append(Message('note_off', note=note, velocity=0, time=step // 2))
        # Move back to keep the cumulative time correct
        # Wait, track.append 'time' is delta time.
        # So: note_on(0), note_off(step/2), note_on(step/2) ...
    
    # --- PHASE 2: IMPACT (1.2s) ---
    # Big chord on impact.
    impact_notes = [48, 60, 64, 67, 72, 79, 84] # C3, C4, E4, G4, C5, G5, C6 (Powerful C Major)
    
    # Current time is around peak_tick. Let's make sure it's exactly at peak_tick.
    # Total time so far: len(arpeggio_notes) * step = peak_tick.
    
    for i, note in enumerate(impact_notes):
        track.append(Message('note_on', note=note, velocity=110, time=0))
        
    # --- PHASE 3: SUSTAIN & END (1.2s to 2.6s) ---
    # Release the impact notes exactly at end_tick.
    # Delta time = end_tick - peak_tick = 2496 - 1152 = 1344 ticks.
    
    track.append(Message('note_off', note=impact_notes[0], velocity=0, time=1344))
    for note in impact_notes[1:]:
        track.append(Message('note_off', note=note, velocity=0, time=0))
        
    mid.save(filename)
    print(f"Synced MIDI saved to: {filename}")

if __name__ == "__main__":
    create_synced_midi('assets/sounds/success_sync_2600ms.mid')
