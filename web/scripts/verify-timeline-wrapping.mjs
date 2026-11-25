import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url);
const {chromium}=require('playwright-core');const fs=require('fs');
const root=fileURLToPath(new URL('../../',import.meta.url)).replace(/\/$/,'');
const http=require('http');const server=http.createServer((req,res)=>{const f=rootPath+'/web/dist'+decodeURIComponent(req.url.split('?')[0]);try{const data=fs.readFileSync(f);res.setHeader('Content-Type',f.endsWith('.js')?'text/javascript':f.endsWith('.css')?'text/css':'application/octet-stream');res.end(data);}catch{res.statusCode=404;res.end();}});const rootPath=root;await new Promise(r=>server.listen(57972,'127.0.0.1',r));
const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
const context=await browser.newContext({viewport:{width:1440,height:1000}});
const user={id:'therapist-fixture',email:'fixture@example.invalid',is_anonymous:false,app_metadata:{provider:'email'},user_metadata:{},aud:'authenticated',created_at:'2026-01-01T00:00:00Z'};
const patient='11111111-1111-4111-8111-111111111111';
await context.addInitScript(({user})=>{localStorage.setItem('cbtipul.web.auth',JSON.stringify({access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:Math.floor(Date.now()/1000)+3600,token_type:'bearer',user}));},{user});
let saved={items:[{id:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',situation:'לשאול שאלה בשיחה עם אדם מוכר',difficulty:80},{id:'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',situation:'להציג רעיון קצר בפני שני אנשים',difficulty:null},{id:'cccccccc-cccc-4ccc-8ccc-cccccccccccc',situation:'לצאת להליכה קצרה במקום מוכר',difficulty:0}]},revision='r1',saves=0,conflict=false;const calls=[];
await context.route('**/*',async route=>{const q=route.request(),u=new URL(q.url());if(q.method()==='OPTIONS')return route.fulfill({status:200,headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-allow-methods':'POST,GET,OPTIONS'}});if(u.hostname==='127.0.0.1'){if(q.isNavigationRequest())return route.fulfill({contentType:'text/html',body:fs.readFileSync(root+'/web/dist/app/index.html','utf8')});return route.continue();}if(!u.hostname.endsWith('supabase.co'))return route.abort();calls.push(u.pathname);let b=q.postData()?q.postDataJSON():{},data=[];
if(u.pathname.endsWith('patient-exposure-hierarchy')){if(b.action==='save'){saves++;if(conflict)return route.fulfill({status:409,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify({error:'revision_conflict'})});saved=b.document;revision='r2';}data={patient_id:patient,document:saved,revision,updated_at:null};}
else if(u.pathname.endsWith('/diary_three_entries'))data=Array.from({length:7},(_,i)=>({id:'diary-'+i,patient_id:patient,created_at:'2026-11-24T12:00:00Z',situation:'תוכן סינתטי'}));
else if(u.pathname.endsWith('/user'))data=user;
else if(u.pathname.endsWith('get-app-context'))data={role:'therapist',entitlement:{access:'full'}};
else if(u.pathname.endsWith('get_my_consent'))data={therapist_id:user.id,consent_type:b.p_consent_type,required_version:b.p_required_version,accepted_version:b.p_required_version,status:'accepted',accepted_at:'2026-10-30T10:00:00Z',revision:1,revoked_at:null};
else if(u.pathname.endsWith('patient-names'))data={names:[{patient_id:patient,name:'מטופלת לדוגמה',revision:'1',updated_at:null}],next_after:null};
else if(u.pathname.endsWith('/Patients'))data={id:patient};
else if(u.pathname.endsWith('load-patients'))data={records:[{id:patient,active:true,notes:null,formulation:{treatmentGoal:'לחזור לפעילויות החשובות לי'},_version:'v'}],next_cursor:null};
else if(u.pathname.endsWith('load-sessions'))data={records:[...Array.from({length:5},(_,i)=>({id:'synthetic-'+i,patient_id:patient,session_date:'2026-11-24',session_type:'intake',notes:'סיכום סינתטי',structured_notes:null,_version:'v'})),{id:'older',patient_id:patient,session_date:'2026-11-16',notes:null,_version:'v'}],next_cursor:null};
else if(u.pathname.endsWith('load-questionnaires'))data={records:[{id:'q1',_version:'v',patient_id:patient,answered_date:'2026-11-24',gad7_answers:[3,3,3,3,3,3,3],phq9_answers:[3,3,3,3,3,3,3,3,3]}],next_cursor:null};
await route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*','content-range':'0-0/1'},body:JSON.stringify(data)});});

const assert=require('node:assert/strict');const page=await context.newPage();const out=root+'/outputs/timeline-wrapping/';fs.mkdirSync(out,{recursive:true});
try {
await page.goto('http://127.0.0.1:57972/app/patients/'+patient+'/overview');await page.locator('.pt-week-items .pt-entry').first().waitFor();
await page.locator('.pt-week-items [data-kind=diary]').first().waitFor();
await page.locator('.pt-week-items [data-kind=questionnaire]').first().waitFor();
for(const width of [2400,1920,1440,900,390]) {
await page.setViewportSize({width,height:1050});await page.waitForTimeout(150);
const stats=await page.evaluate(()=>Array.from(document.querySelectorAll('.pt-week-items')).filter(el=>el.children.length).map(el=>{const cards=Array.from(el.children).map(c=>({w:c.getBoundingClientRect().width,h:c.getBoundingClientRect().height,x:c.getBoundingClientRect().x,y:c.getBoundingClientRect().y,height:getComputedStyle(c).height}));return {cards,width:el.clientWidth,scroll:el.scrollWidth};}));
for(const group of stats){assert(group.scroll<=group.width+1);assert(group.cards.every(c=>Math.abs(parseFloat(c.height)-64)<0.1));assert(Math.max(...group.cards.map(c=>c.w))-Math.min(...group.cards.map(c=>c.w))<1);const first=group.cards[0];for(const c of group.cards.filter((c,i)=>i>0&&c.y>group.cards[i-1].y))assert(Math.abs(c.x-first.x)<1,'last row starts at RTL edge');}
if(width===1920){assert(stats[0].cards[2].y>stats[0].cards[0].y,'dense group wraps');assert(stats[0].cards[0].w<stats.at(-1).cards[0].w,'single card spans its own week');}
assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
await page.screenshot({path:out+width+'.png',fullPage:true});
}
assert(await page.locator('.pt-week-items a').first().getAttribute('title'));
console.log('PASS: equal card heights and within-group widths, RTL incomplete rows, wrapping, independent week widths, no overflow, full hover titles at five viewports');
}finally{await browser.close();server.close();}
