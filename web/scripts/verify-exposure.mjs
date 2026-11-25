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

const assert=require('node:assert/strict');const page=await context.newPage();const out=root+'/outputs/exposure-hierarchy/';
try {
await page.goto('http://127.0.0.1:57972/app/patients/'+patient+'/exposure_hierarchy');await page.getByRole('button',{name:'עריכה',exact:true}).waitFor();
await page.screenshot({path:out+'web-reading.png'});assert.equal(await page.locator('.exposure-list li').count(),3);assert.equal(await page.locator('.exposure-score').nth(2).innerText(),'0%');
await page.getByRole('button',{name:'עריכה',exact:true}).click();await page.getByRole('button',{name:'הזזת מצב 3 למעלה',exact:true}).click();assert.equal(await page.locator('textarea').nth(1).inputValue(),saved.items[2].situation);assert.equal(saves,0);
page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'ביטול עריכה',exact:true}).click();assert.equal(await page.locator('.exposure-content').nth(1).innerText(),saved.items[1].situation);
await page.getByRole('button',{name:'עריכה',exact:true}).click();await page.setViewportSize({width:1440,height:1800});await page.getByRole('button',{name:'גרירת מצב 3',exact:true}).dragTo(page.locator('.exposure-list li').first());assert.equal(await page.locator('textarea').first().inputValue(),saved.items[2].situation);
await page.getByRole('button',{name:'שמירה',exact:true}).click();await page.getByText('המדרג נשמר',{exact:true}).waitFor();assert.equal(saves,1);assert.deepEqual(saved.items.map(x=>x.difficulty),[0,80,null]);
await page.reload();await page.getByRole('button',{name:'עריכה',exact:true}).click();assert.equal(await page.locator('textarea').first().inputValue(),saved.items[0].situation);
await page.locator('textarea').first().fill('שינוי סינתטי שנשמר בטיוטה');conflict=true;await page.getByRole('button',{name:'שמירה',exact:true}).click();await page.getByText('המדרג השתנה במכשיר אחר. השינויים שלכם נשארו כאן.',{exact:true}).waitFor();assert.equal(await page.locator('textarea').first().inputValue(),'שינוי סינתטי שנשמר בטיוטה');assert.equal(await page.getByRole('button',{name:'שמירה',exact:true}).isDisabled(),true);await page.screenshot({path:out+'web-conflict.png'});
// Fresh sharing view; no private record or context loads are allowed here.
await page.close();const share=await context.newPage();calls.length=0;await share.goto('http://127.0.0.1:57972/app/shared/'+patient+'/exposure_hierarchy');await share.getByRole('button',{name:'עריכה',exact:true}).click();await share.screenshot({path:out+'web-sharing-edit.png'});
assert(!calls.some(x=>/load-sessions|load-questionnaires|load-patients|suggest|analy/.test(x)));
await share.getByRole('button',{name:'הזזת מצב 1 למטה',exact:true}).focus();await share.keyboard.press('Enter');assert.equal(await share.locator('textarea').first().inputValue(),saved.items[1].situation);
await share.locator('.exposure-list li').last().scrollIntoViewIfNeeded();const actionBounds=await share.getByRole('button',{name:'שמירה',exact:true}).boundingBox();assert(actionBounds&&actionBounds.y>=0&&actionBounds.y+actionBounds.height<1000);await share.evaluate(()=>scrollTo(0,0));await share.setViewportSize({width:390,height:844});await share.screenshot({path:out+'web-narrow.png',fullPage:true});assert(await share.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
console.log('PASS: reading, zero/null, keyboard move, pointer drag, cancel, single save, reopen order, conflict retention, shared privacy, narrow overflow');
} finally {await browser.close();server.close();}
