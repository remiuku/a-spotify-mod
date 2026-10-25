from pathlib import Path
import subprocess, tempfile
root=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='asm-tempo-') as tmp:
    capture=Path(tmp)/'capture'; estimator=Path(tmp)/'estimate'
    subprocess.run(['cc','-x','c','-std=c11','-O2','-Wall','-Wextra','-Werror','-I'+str(root/'Sources/EeveeSpotifyC/include'),
        str(root/'Sources/EeveeSpotifyC/ASMTempoCapture.m'),str(root/'Tests/ASMTempoCapture/main.c'),'-lm','-o',str(capture)],check=True)
    subprocess.run([str(capture)],check=True)
    files=['Karaoke/Dancer/ASMDancerPolicy.swift','Karaoke/Dancer/ASMTempoEstimator.swift','Karaoke/Dancer/ASMDJInfoTempoPolicy.swift','Karaoke/Library/ASMSongLyricsPolicy.swift']
    subprocess.run(['swiftc']+[str(root/'Sources/EeveeSpotify'/p) for p in files]+[str(root/'Tests/ASMTempoEstimator/main.swift'),'-o',str(estimator)],check=True)
    for bpm in [60,80,90,100,120,128,150,172,200]:
        onsets=subprocess.check_output([str(capture),str(bpm)])
        output=subprocess.check_output([str(estimator),'--pcm'],input=onsets,text=False).decode().strip()
        assert output!='none' and abs(float(output)-bpm)<2,(bpm,output)
    print('PASS real PCM -> C onset capture -> Swift estimation: 9 tempos, tonal background, 48 kHz, odd callback sizes, no audio writes')
