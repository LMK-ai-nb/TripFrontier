import http from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve,sep,extname} from 'node:path';
const root=resolve(import.meta.dirname,'../web');
const mime={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.svg':'image/svg+xml','.txt':'text/plain; charset=utf-8'};
http.createServer(async(req,res)=>{
  try{
    const path=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
    const file=resolve(root,'.'+(path==='/'?'/index.html':path));
    if(!file.startsWith(root+sep)){res.writeHead(403);res.end();return;}
    const data=await readFile(file);res.writeHead(200,{'Content-Type':mime[extname(file)]||'application/octet-stream','X-Content-Type-Options':'nosniff','Cache-Control':'no-store'});res.end(data);
  }catch{res.writeHead(404);res.end('Not found');}
}).listen(4186,'127.0.0.1',()=>console.log('TripFrontier: http://127.0.0.1:4186'));
