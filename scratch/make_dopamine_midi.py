import mido
from mido import Message, MidiFile, MidiTrack, MetaMessage

def create_dopamine_midi(filename):
    mid = MidiFile()
    track = MidiTrack()
    mid.tracks.append(track)
    
    # 120 BPM (1 beat = 500ms)
    track.append(MetaMessage('set_tempo', tempo=500000))
    ticks_per_beat = mid.ticks_per_beat
    
    # --- 定義 ---
    # 1.2s = 2.4 beats = 1152 ticks (Peak)
    # 2.6s = 5.2 beats = 2496 ticks (End)
    peak_tick = 1152
    end_tick = 2496

    # --- PHASE 1: THE CHARGE (0.0s - 1.2s) ---
    # A Major Add9 Arpeggio (Rising fast)
    # Notes: A2, E3, A3, C#4, E4, A4, B4, C#5, E5, G#5, A5, B5
    arp_notes = [45, 52, 57, 61, 64, 69, 71, 73, 76, 80, 81, 83]
    step = peak_tick // len(arp_notes)
    
    for i, note in enumerate(arp_notes):
        # 収束に向けて加速し、音量も上げる
        velocity = 50 + int((i / len(arp_notes)) * 40)
        track.append(Message('note_on', note=note, velocity=velocity, time=0 if i == 0 else step))
        # 音を短く切って、粒立ちを良くする
        track.append(Message('note_off', note=note, velocity=0, time=step // 4))
        # 次のノートまでの待ち時間を調整（delta timeの帳尻合わせ）
        # 次のnote_onは step 周期なので、ここで step * 3/4 待つ
        # ただし最後の音はインパクトに繋げるため調整
        if i < len(arp_notes) - 1:
            track.append(Message('note_on', note=note, velocity=0, time=0)) # dummy
            # 実際には次のループのnote_onでstep分進むので、ここでは何もしない

    # --- PHASE 2: THE GOLDEN IMPACT (1.2s) ---
    # Amaj9 (High-end luxury chord)
    # A1(低音の支え), A3, E4, G#4, B4, C#5, E5, A5
    impact_notes = [33, 57, 64, 68, 71, 73, 76, 81]
    
    # インパクトの瞬間にベロシティ最大
    for note in impact_notes:
        track.append(Message('note_on', note=note, velocity=115, time=0))

    # --- PHASE 3: THE AFTERGLOW (1.2s - 2.6s) ---
    # 2.6sまで音を持続させ、最後に消す
    # デルタタイム = end_tick - peak_tick
    duration_ticks = end_tick - peak_tick
    
    track.append(Message('note_off', note=impact_notes[0], velocity=0, time=duration_ticks))
    for note in impact_notes[1:]:
        track.append(Message('note_off', note=note, velocity=0, time=0))

    mid.save(filename)
    print(f"Dopamine Sync MIDI saved to: {filename}")

if __name__ == "__main__":
    create_dopamine_midi('assets/sounds/dopamine_sync_2600ms.mid')
