import os,subprocess,tempfile
from pathlib import Path
root=Path.cwd()
with tempfile.TemporaryDirectory(prefix='desaku-live-') as tmp:
 result=subprocess.run(['Godot_v4.7.2-stable_win64_console.exe','--headless','--path',str(root),'--script','res://tests/test_live_beta.gd'],env=dict(os.environ,APPDATA=tmp),capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=600)
 (root/'build/live-beta-results.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 print(result.stdout+result.stderr)
 raise SystemExit(result.returncode)
