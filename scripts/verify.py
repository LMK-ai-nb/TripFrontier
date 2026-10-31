"""Reproducible local verification, with exact commands/results saved as JSON.

Native is opt-in because Windows needs MSVC and an SDK. Browser is opt-in and
needs Playwright/Chromium. This script never pushes, logs in or publishes.
"""
import argparse, json, os, pathlib, socket, subprocess, sys, time, urllib.request
root=pathlib.Path(__file__).resolve().parent.parent
artifacts=root/'artifacts';artifacts.mkdir(exist_ok=True)
results=[]

def run(*command):
    start=time.perf_counter()
    try:
        p=subprocess.run(list(command),cwd=root,text=True,encoding='utf-8',errors='replace',capture_output=True)
        result={'command':list(command),'exit_code':p.returncode,'seconds':round(time.perf_counter()-start,4),'stdout':p.stdout,'stderr':p.stderr}
    except OSError as e:result={'command':list(command),'exit_code':-1,'error':str(e)}
    results.append(result)
    print(('PASS ' if result['exit_code']==0 else 'FAIL ')+' '.join(command),flush=True)
    if result['exit_code']!=0:
        print(result.get('stdout','')+result.get('stderr',result.get('error','')))
        raise RuntimeError('Verification step failed')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser',action='store_true');parser.add_argument('--native',action='store_true');args=parser.parse_args()
    passed=False
    try:
        run('moon','version','--all')
        run('moon','check','--target','all','--deny-warn')
        for target in ['wasm','wasm-gc','js']+(['native'] if args.native else []):
            run('moon','test','--target',target,'--deny-warn')
            run('moon','build','--target',target,'--deny-warn')
        run('moon','fmt','--check');run('moon','info')
        run('git','diff','--exit-code','--','*.mbti')
        run('moon','run','cmd/demo')
        run('node','scripts/build.mjs')
        run('node','--test','tests/cli.test.mjs')
        run(sys.executable,'-m','unittest','discover','-s','tests','-p','test_gtfs.py')
        run(sys.executable,'tests/oracle.py')
        run(sys.executable,'scripts/package_check.py')
        if args.browser:
            with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
            env=os.environ.copy();env['TRIPFRONTIER_PORT']=str(port)
            with (artifacts/'preview.log').open('w',encoding='utf-8') as log:
                server=subprocess.Popen(['node','scripts/serve.mjs'],cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT)
                try:
                    for attempt in range(40):
                        if server.poll() is not None:raise RuntimeError('Preview process exited')
                        try:urllib.request.urlopen(f'http://127.0.0.1:{port}',timeout=1).close();break
                        except OSError:time.sleep(.1)
                    else:raise RuntimeError('Preview unavailable')
                    run(sys.executable,'tests/browser.py',f'http://127.0.0.1:{port}')
                finally:server.terminate();server.wait(timeout=5)
        passed=True
    finally:
        data={'date':'2026-10-31','passed':passed,'native_requested':args.native,'browser_requested':args.browser,'steps':results}
        (artifacts/'validation.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return 0 if passed else 1

if __name__=='__main__':
    try:sys.exit(main())
    except RuntimeError as e:print(str(e),file=sys.stderr);sys.exit(1)
