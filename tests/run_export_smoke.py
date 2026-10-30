"""Launch an exported executable twice, in isolated save data, and verify exit/logs."""
import argparse,os,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('executable');p.add_argument('captures');args=p.parse_args()
exe=Path(args.executable).resolve();captures=Path(args.captures).resolve();captures.mkdir(parents=True,exist_ok=True)
with tempfile.TemporaryDirectory(prefix='desaku-export-') as tmp:
 env=dict(os.environ,APPDATA=tmp,DESAKU_CAPTURE_DIR=str(captures))
 for suffix in [[],['--beta-restore']]:
  mode='restore' if suffix else 'smoke'
  log=Path(tmp)/(mode+'.log')
  result=subprocess.run([str(exe),'--log-file',str(log),'--','--beta-smoke',*suffix],env=env,timeout=100)
  output=log.read_text(encoding='utf-8',errors='replace') if log.exists() else ''
  (captures/(mode+'.log')).write_text(output,encoding='utf-8')
  print(output)
  assert result.returncode==0 and 'EXPORTED BETA TEST: PASS' in output and 'ERROR' not in output,mode+' failed'
print('EXPORTED RENDER, SOAK AND RESTART: PASS')
