from pathlib import Path
import subprocess, tempfile

root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='asm-notification-') as tmp:
    exe = Path(tmp)/'notification-test'
    subprocess.run(['swiftc',
        str(root/'Sources/EeveeSpotify/Shared/Helpers/ASMMainNotificationDelivery.swift'),
        str(root/'Tests/ASMMainNotificationDelivery/main.swift'), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True, timeout=5)
    try:
        result = subprocess.run([str(exe), '--blocking-reference'], capture_output=True, timeout=1)
    except subprocess.TimeoutExpired:
        print('PASS counterexample: original OperationQueue.main observer deadlocks the same real background-player/main dependency; patched observer completes')
    else:
        raise AssertionError('Original synchronous observer unexpectedly returned: '+str(result.returncode))
