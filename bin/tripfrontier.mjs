#!/usr/bin/env node
import {readFileSync,writeFileSync,statSync} from 'node:fs';
const args=process.argv.slice(2);
if(args.length===1&&['--help','-h'].includes(args[0])){
  console.log('Usage: node bin/tripfrontier.mjs <request.json|-> [--out report.json]\nExit 0: complete frontier; 1: unreachable within supplied data/model; 2: invalid input, search limit or I/O.');process.exit(0);
}
if(![1,3].includes(args.length)||(args.length===3&&args[1]!=='--out')){console.error('Use --help for usage.');process.exit(2);}
try{
  if(args[0]!=='-'&&statSync(args[0]).size>33554432)throw Error('transport file limit exceeded');
  const source=readFileSync(args[0]==='-'?0:args[0],'utf8');
  if(source.length>8388608)throw Error('input exceeds 8 Mi UTF-16 units');
  const {route_request}=await import('../dist/engine.js');
  const raw=route_request(source),report=JSON.parse(raw);
  if(args.length===3)writeFileSync(args[2],raw+'\n');
  process.stdout.write(raw+'\n');
  process.exitCode=report.error?2:report.status==='unreachable'?1:0;
}catch(error){console.error(JSON.stringify({error:{code:'IO_OR_RUNTIME',message:error.message}}));process.exitCode=2;}
