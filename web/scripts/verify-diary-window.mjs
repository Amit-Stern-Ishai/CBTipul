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
else if(u.pathname.endsWith('/user'))data=user;
else if(u.pathname.endsWith('get-app-context'))data={role:'therapist',entitlement:{access:'full'}};
else if(u.pathname.endsWith('get_my_consent'))data={therapist_id:user.id,consent_type:b.p_consent_type,required_version:b.p_required_version,accepted_version:b.p_required_version,status:'accepted',accepted_at:'2026-10-30T10:00:00Z',revision:1,revoked_at:null};
else if(u.pathname.endsWith('patient-names'))data={names:[{patient_id:patient,name:'מטופלת לדוגמה',revision:'1',updated_at:null}],next_after:null};
else if(u.pathname.endsWith('/Patients'))data={id:patient};
else if(u.pathname.endsWith('load-patients'))data={records:[{id:patient,active:true,notes:null,formulation:{treatmentGoal:'לחזור לפעילויות החשובות לי'},_version:'v'}],next_cursor:null};
else if(u.pathname.endsWith('load-sessions'))data={records:[{id:'synthetic-session',patient_id:patient,session_date:'2026-11-24',session_type:'intake',notes:'סיכום סינתטי לבדיקת עיצוב',structured_notes:null,_version:'v'}],next_cursor:null};
else if(u.pathname.endsWith('load-questionnaires'))data={records:[],next_cursor:null};
await route.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*','access-control-allow-headers':'*','content-range':'0-0/1'},body:JSON.stringify(data)});});

const assert=require('node:assert/strict');const page=await context.newPage();const out=root+'/outputs/diary-window/';fs.mkdirSync(out,{recursive:true});
try {
for(const type of ['diary_one','diary_two','diary_three']) {
await page.setViewportSize({width:1440,height:900});
await page.goto('http://127.0.0.1:57972/app/patients/'+patient+'/'+type);
await page.getByRole('button',{name:'רשומה חדשה',exact:true}).click();
const dialog=page.getByRole('dialog');await dialog.waitFor();const field=dialog.locator('textarea').first();await field.waitFor();
const bounds=await field.boundingBox();assert(bounds.y<350,JSON.stringify(bounds));
await field.fill('טקסט סינתטי לבדיקת שמירת הטיוטה במעבר בין תצוגות');
await dialog.getByRole('button',{name:'היומן המלא',exact:true}).click();assert.equal(await dialog.locator('textarea').first().inputValue(),'טקסט סינתטי לבדיקת שמירת הטיוטה במעבר בין תצוגות');
await dialog.getByRole('button',{name:'חלק אחד',exact:true}).click();
await page.screenshot({path:out+type+'-desktop.png'});
await page.setViewportSize({width:390,height:844});await page.screenshot({path:out+type+'-narrow.png'});
assert(await dialog.evaluate(el=>el.scrollWidth<=el.clientWidth));
page.once('dialog',d=>d.dismiss());await page.keyboard.press('Escape');assert(await dialog.isVisible());assert.equal(await field.inputValue(),'טקסט סינתטי לבדיקת שמירת הטיוטה במעבר בין תצוגות');
page.once('dialog',d=>d.accept());await dialog.getByRole('button',{name:'ביטול',exact:true}).click();await dialog.waitFor({state:'detached'});
}
console.log('PASS: all three diaries, immediate writing area, mode-switch draft preservation, narrow overflow, Escape/cancel dirty protection');
} finally {await browser.close();server.close();}
