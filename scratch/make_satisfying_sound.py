import wave
import struct
import math
import os

def generate_satisfying_sound(filename, sample_rate=44100):
    # Parameters for a "satisfying" double chime
    # Chime 1: A Major triad starting at t=0
    # Chime 2: A Major triad (higher octave) starting at t=0.15s
    
    duration = 0.8
    num_samples = int(duration * sample_rate)
    
    # Frequencies for A Major
    chime1_freqs = [440.0, 554.37, 659.25] # A4, C#5, E5
    chime2_freqs = [880.0, 1108.73, 1318.51] # A5, C#6, E6
    
    chime2_start_t = 0.15
    chime2_start_sample = int(chime2_start_t * sample_rate)
    
    # Ensure directory exists
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            t = float(i) / sample_rate
            value = 0
            
            # Chime 1
            env1 = math.exp(-t * 8.0)
            for freq in chime1_freqs:
                value += 0.3 * math.sin(2.0 * math.pi * freq * t) * env1
            
            # Chime 2 (Delayed)
            if i >= chime2_start_sample:
                t2 = t - chime2_start_t
                env2 = math.exp(-t2 * 10.0)
                for freq in chime2_freqs:
                    value += 0.4 * math.sin(2.0 * math.pi * freq * t2) * env2
            
            # Soft clipping and scaling to 16-bit range
            sample = max(-1, min(1, value))
            int_sample = int(sample * 32767)
            
            wav_file.writeframes(struct.pack('<h', int_sample))

if __name__ == "__main__":
    output_path = "assets/sounds/success.wav"
    generate_satisfying_sound(output_path)
    print(f"Sound generated: {output_path}")
