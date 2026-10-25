from pathlib import Path
import subprocess, tempfile

root = Path(__file__).resolve().parents[2]
source = root/'Sources/EeveeSpotify/Premium/Helpers/SpotifyResponsePatcher.swift'
# The network hook must allow the request to reach the response code tested
# below. Reject the old pre-response cancellation as an integration guard.
network = (root/'Sources/EeveeSpotify/SessionProtection.x.swift').read_text()
assert 'Cancelled customize re-fetch' not in network
start = network.index('if url.isCustomize {')
end = network.index('// bootstraps pass through', start)
assert 'orig.resume()' in network[start:end] and 'task.cancel()' not in network[start:end]
with tempfile.TemporaryDirectory(prefix='asm-configuration-') as tmp:
    tmp = Path(tmp)
    # FoundationNetworking is split out on Linux; compile the actual patcher.
    patcher = tmp/'SpotifyResponsePatcher.swift'
    patcher.write_text('import FoundationNetworking\n'+source.read_text())
    exe = tmp/'configuration-test'
    subprocess.run(['swiftc', '-swift-version', '5', str(patcher),
        str(root/'Sources/EeveeSpotify/Shared/Models/Extensions/URL+Extension.swift'),
        str(root/'Sources/EeveeSpotify/Premium/Models/EeveePatchType.swift'),
        str(root/'Tests/SpotifyResponsePatcher/Stubs.swift'),
        str(root/'Tests/SpotifyResponsePatcher/main.swift'), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True, timeout=8)

