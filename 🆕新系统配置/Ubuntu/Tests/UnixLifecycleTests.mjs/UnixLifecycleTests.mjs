#!/usr/bin/env node
// 仅在临时目录使用假系统、假包数据库和假包管理器，不安装本机软件。
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const entryDir=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(entryDir,'../../..');
const work=fs.mkdtempSync(path.join(os.tmpdir(),'Jobs Unix 中文 空格-'));
const bin=path.join(work,'bin');fs.mkdirSync(bin);
const mock=`#!${process.execPath}
const fs=require('node:fs'),path=require('node:path');
const command=path.basename(process.argv[1]), args=process.argv.slice(2), pkg=args.at(-1), dbDir=process.env.MOCK_DB;
const has=p=>fs.existsSync(path.join(dbDir,p)); const get=p=>has(p)?fs.readFileSync(path.join(dbDir,p),'utf8'):'';
const put=p=>fs.writeFileSync(path.join(dbDir,p),'1.0'); const remove=p=>{if(has(p))fs.unlinkSync(path.join(dbDir,p));};
const ok=v=>{if(v)process.stdout.write(v+'\\n');process.exit(0);}; const no=()=>process.exit(1);
const action=(name,p)=>{fs.appendFileSync(process.env.MOCK_ACTIONS,name+' '+p+'\\n');if(process.env.MOCK_FAIL===p)no();put(p);if(process.env.MOCK_BUNDLE==='1'&&(p==='node'||p==='nodejs'))put('npm');ok();};
if(command==='uname')ok(args[0]==='-s'?process.env.MOCK_OS:'x86_64');
if(command==='id')ok('0');
if(command==='stat')ok(args[1].includes('u')?'0':'700');
if(command==='apt-get'||command==='dnf'||command==='apk'||command==='pkg'||command==='rpm'||command==='dpkg-query'||command==='dpkg'){
 if(args.includes('--version')||args[0]==='-v'||args[0]==='-N')ok('mock 1.0');
 if(command==='apt-get'&&args[0]==='update')ok('mock index refreshed');
 if(command==='dpkg-query'){if(has(pkg))ok('installed\\t'+get(pkg));no();}
 if(command==='rpm'&&args[0]==='-q'){if(has(pkg))ok(get(pkg));process.stdout.write('package '+pkg+' is not installed\\n');no();}
 if(command==='pkg'&&args[0]==='query'){if(!has(pkg))no();ok(args[1]==='%?r'?(process.env.MOCK_SHARED===pkg?'1':'0'):get(pkg));}
 if(command==='apk'&&args[0]==='info'){if(!has(pkg))no();ok(args[1]==='-v'?pkg+'-'+get(pkg):'');}
 if(command==='apk'&&args.includes('--simulate')){if(process.env.MOCK_SHARED===pkg)ok('(1/2) Purging '+pkg+' (1.0)\\n(2/2) Purging shared-library (1.0)');ok('(1/1) Purging '+pkg+' (1.0)');}
 if(args.includes('install')||args.includes('reinstall')||args[0]==='add'||args[0]==='fix')action('install',pkg);
 if(command==='dpkg'||(command==='rpm'&&args[0]==='-e')||args[0]==='del'||args.includes('delete')){if(process.env.MOCK_SHARED===pkg)no();fs.appendFileSync(process.env.MOCK_ACTIONS,'remove '+pkg+'\\n');remove(pkg);ok();}
 no();
}
const mapping={'git':'git','git-lfs':'git-lfs','curl':'curl','wget':'wget','zsh':'zsh','fzf':'fzf','python3':'python3','node':process.env.MOCK_OS==='FreeBSD'?'node':'nodejs','npm':'npm','make':'build-essential','gmake':'gmake','pkg-config':'pkg-config','cc':'gcc'};
const toolPkg=mapping[command];if(!toolPkg)no();
if(process.env.MOCK_BROKEN===toolPkg)no();
if(has(toolPkg))ok('mock healthy');no();
`;
for(const cmd of ['uname','id','stat','apt-get','dnf','apk','pkg','rpm','dpkg','dpkg-query','git','git-lfs','curl','wget','zsh','fzf','python3','node','npm','make','gmake','cc','pkg-config'])fs.writeFileSync(path.join(bin,cmd),mock,{mode:0o755});
let checks=0;
const platforms=[['Ubuntu','ubuntu','Linux'],['Debian','debian','Linux'],['RockyLinux','rocky','Linux'],['AlibabaCloudLinux','alinux','Linux'],['Alpine','alpine','Linux'],['FreeBSD','','FreeBSD']];
// 每次场景独立状态与环境，源脚本仅在临时副本替换系统文件和状态位置。
for(const [platform,distro,host] of platforms){
 const dir=path.join(work,platform);fs.mkdirSync(dir);const db=path.join(dir,'db');fs.mkdirSync(db);const state=path.join(dir,'state',platform);fs.mkdirSync(path.dirname(state));const actions=path.join(dir,'actions');fs.writeFileSync(actions,'');
 const osRelease=path.join(dir,'os-release');fs.writeFileSync(osRelease,'ID="'+distro+'"\n');
 const filename='【'+platform+'】🆕新系统配置.sh';const source=path.join(root,platform,filename,filename);assert(fs.existsSync(source),source);
 let content=fs.readFileSync(source,'utf8').replaceAll('/etc/os-release',osRelease).replace(`STATE_ROOT='${platform==='FreeBSD'?'/var/db':'/var/lib'}/jobs-new-system/${platform}'`,`STATE_ROOT='${state}'`);
 const script=path.join(dir,filename);fs.writeFileSync(script,content);
 const env={...process.env,PATH:bin+':/usr/bin:/bin',MOCK_DB:db,MOCK_OS:host,MOCK_ACTIONS:actions,TERM:'dumb',NO_COLOR:'1'};
 const run=(args=[],extra={})=>spawnSync('/bin/sh',[script,...args],{env:{...env,...extra},encoding:'utf8',cwd:work,timeout:15000});
 const good=(result,label)=>{assert.equal(result.status,0,platform+' '+label+'\n'+result.stdout+'\n'+result.stderr);checks++;};
 const bad=(result,label)=>{assert.notEqual(result.status,0,platform+' '+label);checks++;};
 // 入口随平台目录复制/改名后，从工程外调用；临时后端只记录原始argv和退出码。
 const uninstallName='【'+platform+'】↩️卸载新系统配置.sh';
 const packageRoot=path.join(dir,'复制 中文 空格',platform);fs.mkdirSync(packageRoot,{recursive:true});
 const wrapperDir=path.join(packageRoot,uninstallName);fs.mkdirSync(wrapperDir);
 const wrapper=path.join(wrapperDir,uninstallName);fs.copyFileSync(path.join(root,platform,uninstallName,uninstallName),wrapper);
 const packagedBackendDir=path.join(packageRoot,filename);fs.mkdirSync(packagedBackendDir);
 const packagedBackend=path.join(packagedBackendDir,filename);const capture=path.join(dir,'wrapper-argv');
 fs.writeFileSync(packagedBackend,'#!/bin/sh\nprintf "<%s>\\n" "$@" > "$MOCK_WRAPPER_CAPTURE"\nexit "${MOCK_WRAPPER_STATUS:-0}"\n');
 const wrapperRun=(args=[],extra={})=>spawnSync('/bin/sh',[wrapper,...args],{env:{...env,MOCK_WRAPPER_CAPTURE:capture,...extra},encoding:'utf8',cwd:work,timeout:15000});
 good(wrapperRun(),'uninstall wrapper default help');assert(!fs.existsSync(capture));checks++;
 good(wrapperRun(['--help']),'uninstall wrapper help');assert(!fs.existsSync(capture));checks++;
 good(wrapperRun(['--list']),'uninstall wrapper list');assert.equal(fs.readFileSync(capture,'utf8'),'<--list>\n');checks++;fs.unlinkSync(capture);
 for(const args of [['--install'],['--plan'],['--uninstall'],['--repair'],['--unknown'],['--help','--yes'],['--list','--components','git'],['--components'],['--components','git','--yes','--install'],['--install','--components','git','--yes']]){
   assert.equal(wrapperRun(args).status,2,platform+' refuses conflicting arguments: '+args.join(' '));checks++;
   assert(!fs.existsSync(capture),'invalid invocation must not call backend');checks++;
 }
 good(wrapperRun(['--components','git curl;literal','--yes']),'uninstall wrapper literal argv');assert.equal(fs.readFileSync(capture,'utf8'),'<--uninstall>\n<--components>\n<git curl;literal>\n<--yes>\n');checks++;fs.unlinkSync(capture);
 good(wrapperRun(['--components=git,curl','--yes']),'uninstall wrapper equals syntax');assert.equal(fs.readFileSync(capture,'utf8'),'<--uninstall>\n<--components=git,curl>\n<--yes>\n');checks++;fs.unlinkSync(capture);
 for(const status of [37,130,143]){assert.equal(wrapperRun(['--components','git','--yes'],{MOCK_WRAPPER_STATUS:String(status)}).status,status,platform+' propagates backend status');checks++;fs.unlinkSync(capture);}
 fs.unlinkSync(packagedBackend);bad(wrapperRun(['--components','git','--yes']),'uninstall wrapper missing backend');assert(!fs.existsSync(capture));checks++;
 fs.writeFileSync(packagedBackend,content);
 bad(wrapperRun(['--yes']),'uninstall wrapper requires explicit components');assert(!fs.existsSync(state));checks++;
 bad(wrapperRun(['--components','git']),'uninstall wrapper nonTTY cancellation');assert(!fs.existsSync(state));checks++;
 good(run(['--list']),'list');good(run(),'default plan');assert(!fs.existsSync(state));checks++;
 bad(run(['--install','--yes']),'explicit selection');assert(!fs.existsSync(state));checks++;
 bad(run(['--install','--components','git','--yes'],{MOCK_OS:host==='Linux'?'Darwin':'Linux'}),'wrong OS');
 bad(run(['--install','--components','git']),'nonTTY cancellation');assert(!fs.existsSync(state));checks++;
 good(run(['--install','--components','git','--yes']),'install');assert.equal(fs.readFileSync(path.join(db,'git'),'utf8'),'1.0');checks++;
 const before=fs.readFileSync(actions,'utf8');good(run(['--install','--components','git','--yes']),'repeat');assert.equal(fs.readFileSync(actions,'utf8'),before);checks++;
 good(wrapperRun(['--components','git','--yes']),'owned uninstall through dedicated entry');assert(!fs.existsSync(path.join(db,'git')));checks++;
 fs.writeFileSync(path.join(db,'git'),'original');good(run(['--install','--components','git','--yes']),'reuse existing');bad(run(['--uninstall','--components','git','--yes']),'unowned preserved');assert.equal(fs.readFileSync(path.join(db,'git'),'utf8'),'original');checks++;fs.unlinkSync(path.join(db,'git'));
 good(run(['--install','--components','git','--yes']),'reinstall own');fs.writeFileSync(path.join(db,'git'),'2.0');bad(run(['--uninstall','--components','git','--yes']),'version changed');assert(fs.existsSync(path.join(db,'git')));checks++;fs.writeFileSync(path.join(db,'git'),'1.0');
 bad(run(['--uninstall','--components','git','--yes'],{MOCK_SHARED:'git'}),'shared preserved');assert(fs.existsSync(path.join(db,'git')));checks++;
 good(run(['--install','--components','node','--yes'],{MOCK_BUNDLE:'1'}),'bundled explicit packages');assert(fs.existsSync(path.join(state,'receipts','npm')));checks++;good(run(['--uninstall','--components','node','--yes']),'reverse component removal');
 bad(run(['--install','--components','git','--yes'],{MOCK_BROKEN:'git'}),'automatic repair with failed recheck');
 bad(run(['--install','--components','curl','--yes'],{MOCK_FAIL:'curl'}),'install fails');assert(!fs.existsSync(path.join(state,'operation.lock')));checks++;
 bad(run(['--uninstall','--components','curl','--yes']),'pending preserved');good(run(['--install','--components','curl','--yes']),'retry missing pending');
 fs.mkdirSync(path.join(state,'operation.lock'));bad(run(['--install','--components','wget','--yes']),'lock');assert(!fs.existsSync(path.join(db,'wget')));checks++;fs.rmdirSync(path.join(state,'operation.lock'));
 bad(run(['--install','--components','node,,git','--yes']),'empty ID');bad(run(['--install','--components','unknown','--yes']),'unknown ID');
 console.log(platform+': isolated lifecycle checks passed');
}
console.log(checks+' assertions passed. Fixture: '+work);
