import {readFileSync} from 'node:fs';
import {route_request} from '../dist/engine.js';
const requests=JSON.parse(readFileSync(0,'utf8'));
process.stdout.write(JSON.stringify(requests.map(x=>JSON.parse(route_request(JSON.stringify(x))))));
