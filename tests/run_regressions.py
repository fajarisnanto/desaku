"""Run bounded Godot regressions in temporary app data, preserving the user's village."""
import argparse, json, os, subprocess, tempfile, time
from pathlib import Path
parser=argparse.ArgumentParser()
parser.add_argument('--godot',default='Godot_v4.7.2-stable_win64_console.exe')
args=parser.parse_args()
root=Path(__file__).resolve().parent.parent
commands=[
 ('navigation',['--','--self-test']),
 ('social',['--','--social-test']),
 ('ui',['--script','res://tests/test_ui.gd']),
 ('offices',['--script','res://tests/test_offices.gd']),
 ('news',['--script','res://tests/test_news.gd']),
]
results=[]
with tempfile.TemporaryDirectory(prefix='desaku-tests-') as temp:
 env=dict(os.environ,APPDATA=temp)
 for name,tail in commands:
  start=time.perf_counter()
  try:
   run=subprocess.run([args.godot,'--headless','--path',str(root),*tail],env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)
   output=run.stdout+run.stderr
   passed=run.returncode==0 and 'PASS' in output and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
  except subprocess.TimeoutExpired as error:
   output='TIMEOUT: '+str(error);passed=False
  results.append({'name':name,'passed':passed,'seconds':round(time.perf_counter()-start,2),'output':output})
  print(name+': '+('PASS' if passed else 'FAIL'),flush=True)
  if not passed:print(output,flush=True)
 report=root/'build/beta-regression-results.json';report.parent.mkdir(exist_ok=True)
 report.write_text(json.dumps(results,indent=2),encoding='utf-8')
raise SystemExit(0 if all(row['passed'] for row in results) else 1)
