import {test,expect,type BrowserContext,type Page} from '@playwright/test';
import {createWorksheet,type WorksheetType} from '../src/workspace/model';
const patient='11111111-1111-4111-8111-111111111111', other='22222222-2222-4222-8222-222222222222';
const user={id:'therapist-fixture',email:'fixture@example.invalid',is_anonymous:false,app_metadata:{provider:'email'},user_metadata:{},aud:'authenticated',created_at:'2026-01-01T00:00:00Z'};
function diary(type:WorksheetType){return {...createWorksheet(type).data,id:'entry',patient_id:patient,created_by:'patient',created_at:'2026-10-30T12:00:00Z',updated_at:'2026-10-30T12:00:00Z',[type==='diary_three'?'situation':'event']:'אירוע סינתטי',automatic_thoughts:type==='diary_three'?[{text:'מחשבה סינתטית',beliefBefore:80,beliefAfter:20}]:['מחשבה סינתטית'],feelings:type==='diary_three'?[{name:'עצב',intensityBefore:70,intensityAfter:20}]:[{name:'עצב',intensity:70}],thinking_errors:[],alternative_thoughts:type==='diary_three'?[{text:'חלופה סינתטית',belief:80}]:['חלופה סינתטית'],behaviour:'פעולה סינתטית',physical_symptoms:''};}
async function fixture(context:BrowserContext,options:{readOnly?:boolean;nameDelay?:Promise<void>;nameFailure?:boolean;missingName?:boolean;nameConsent?:boolean;deny?:boolean;fail?:boolean;uncertain?:boolean;loseAfterSave?:boolean;delay?:Promise<void>}={}) {
 const requests:{path:string;select:string;method:string;body:Record<string,unknown>|null;patient:string|null}[]=[];
 let approved=options.nameConsent!==false;
 const records:Record<string,Record<string,unknown>[]>= {Sessions:[],CombinedMood:[{id:'9007199254740993',patient_id:patient,session_id:null,created_by:'therapist',answered_date:'2026-10-30',gad7_answers:Array(7).fill(1),phq9_answers:Array(9).fill(0),interference_level:1,combined_notes:{gad7:['PRIVATE_NOTE_SENTINEL'],phq9:[],interference:''}}],diary_one_entries:[diary('diary_one')],diary_two_entries:[diary('diary_two')],diary_three_entries:[diary('diary_three')]};
 await context.addInitScript(({user})=>{if(!localStorage.getItem('fixture-seeded')){localStorage.setItem('fixture-seeded','yes');localStorage.setItem('cbtipul.web.auth',JSON.stringify({access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:Math.floor(Date.now()/1000)+3600,token_type:'bearer',user}));}}, {user});
 await context.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.hostname==='127.0.0.1')return route.continue();if(url.hostname!=='fixture-cbtipul.supabase.co')return route.abort();
  const method=req.method(),path=url.pathname,body=req.postData()?req.postDataJSON():null,select=url.searchParams.get('select')??'';
  const headers={'access-control-allow-origin':'*','access-control-allow-headers':'*','access-control-expose-headers':'content-range','content-range':'0-0/1'};
  if(method==='OPTIONS')return route.fulfill({status:200,headers});
  requests.push({path,select,method,body,patient:url.searchParams.get('patient_id')});
  let data:unknown,status=200;
  if(path.endsWith('/user'))data=user;
  else if(path.endsWith('/logout'))data={};
  else if(path.endsWith('/get-app-context'))data={role:'therapist',entitlement:{access:options.readOnly?'read_only':'full'}};
  else if(path.endsWith('/get_my_consent')||path.endsWith('/record_my_consent')){if(path.endsWith('/record_my_consent')&&body.p_consent_type==='patient_name_storage')approved=body.p_decision==='accepted';const ok=body.p_consent_type!=='patient_name_storage'||approved;data={therapist_id:user.id,consent_type:body.p_consent_type,required_version:body.p_required_version,accepted_version:ok?body.p_required_version:null,status:ok?'accepted':'required',accepted_at:ok?'2026-10-30T10:00:00Z':null,revoked_at:null,revision:ok?1:0};}
  else if(path.endsWith('/patient-names')) {
   if(options.nameDelay)await options.nameDelay;
   if(options.nameFailure){status=503;data={code:'service_unavailable'};}
   else data={names:[{patient_id:patient.toUpperCase(),name:options.missingName?null:'מטופלת לדוגמה א',revision:'1',updated_at:null},{patient_id:other,name:'מטופל לדוגמה ב',revision:'2',updated_at:null}],next_after:null};
  }
  else if(path.endsWith('/load-patients'))data={records:[{id:patient,active:true,notes:null,formulation:null,_version:'v'},{id:other,active:true,notes:null,formulation:null,_version:'v'}].filter(r=>!body.id||r.id===body.id),next_cursor:null};
  else if(path.endsWith('/load-sessions')||path.endsWith('/load-questionnaires')) {
    const table=path.endsWith('/load-sessions')?'Sessions':'CombinedMood';
    data={records:records[table].filter(r=>!body.patient_id||r.patient_id===body.patient_id).map(r=>Object.fromEntries(Object.entries({...r,_version:'v'}).filter(([k])=>body.view!=='shared'||!['notes','combined_notes'].includes(k)))),next_cursor:null};
  }
  else if(path.endsWith('/save-session')||path.endsWith('/save-questionnaire')) {
    const table=path.endsWith('/save-session')?'Sessions':'CombinedMood';
    if(options.delay)await options.delay;
    if(options.uncertain){options.uncertain=false;return route.abort('failed');}
    if(options.fail){options.fail=false;status=403;data={error:'access_denied'};}
    else {
      const id=body.mode==='update'?body.id:'created';
      const prev=records[table].find(r=>r.id===id)??{};
      const row={...prev,...body.changes,id,patient_id:patient,_version:'v'};
      records[table]=[row,...records[table].filter(r=>r.id!==id)];
      if(options.loseAfterSave){options.loseAfterSave=false;return route.abort('failed');}
      data={record:Object.fromEntries(Object.entries(row).filter(([k])=>body.view!=='shared'||!['notes','combined_notes'].includes(k)))};
    }
  }
  else if(path.endsWith('/Patients')){if(select==='id'){data={id:url.searchParams.get('id')?.replace('eq.','')};if(options.deny){status=406;data={code:'PGRST116'};}}else{data=[{id:patient,active:true},{id:other,active:true}];headers['content-range']='0-1/2';}}
  else if(path.endsWith('/anonymize-clinical-text'))data={anonymizedText:'סיכום לאחר הסרת פרטים מזהים'};
  else {const table=path.split('/').at(-1)!;if(!(table in records))throw new Error(`Unexpected endpoint ${path}`);if(method==='POST'||method==='PATCH'){
    if(options.delay)await options.delay;
    if(options.uncertain){options.uncertain=false;return route.abort('failed');}
    if(options.fail){options.fail=false;status=403;data={code:'42501'};}else{
      const id=method==='PATCH'?url.searchParams.get('id')!.replace('eq.',''):'created';
      const prev=records[table].find(r=>r.id===id)??{};
      const row={...prev,...body,id,patient_id:patient}; records[table]=[row,...records[table].filter(r=>r.id!==id)];if(options.loseAfterSave){options.loseAfterSave=false;return route.abort('failed');}data=Object.fromEntries(Object.entries(row).filter(([k])=>select.split(',').some(c=>c.split('::')[0]===k)));
    }
   }else{data=records[table].filter(r=>!url.searchParams.get('patient_id')||r.patient_id===url.searchParams.get('patient_id')?.replace('eq.','')).map(r=>Object.fromEntries(Object.entries(r).filter(([k])=>select.split(',').some(c=>c.split('::')[0]===k))));headers['content-range']=`0-${Math.max(0,(data as unknown[]).length-1)}/${(data as unknown[]).length}`;}}
  await route.fulfill({status,contentType:'application/json',headers,body:JSON.stringify(data)});
 });return {requests,records};
}
async function openEntry(page:Page,type:string,shared=false){await page.goto(`/app/${shared?'shared':'patients'}/${patient}/${type}`);await page.locator('.pw-history button').first().click();if(type!=='questionnaire')await page.getByRole('button',{name:'עריכה',exact:true}).click();}

test('consent gates name lookup; choose patient and save directly',async({context,page},info)=>{
 const f=await fixture(context,{nameConsent:false});await page.goto('/app/');await expect(page.getByRole('heading',{name:'שמירת שמות מטופלים וסנכרון בין מכשירים'})).toBeVisible();expect(f.requests.some(r=>r.path.endsWith('/patient-names'))).toBe(false);
 await page.getByRole('button',{name:'אישור והמשך'}).click();await page.getByRole('link',{name:/מטופלת לדוגמה א/}).click();await expect(page.getByRole('heading',{name:'מטופלת לדוגמה א'})).toBeVisible();await page.getByRole('link',{name:'פגישה חדשה',exact:true}).click();await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('סיכום סינתטי');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByRole('status').filter({hasText:'הרשומה נשמרה'})).toBeVisible();expect(f.requests.filter(r=>r.path.endsWith('/save-session')&&r.body?.mode==='create')).toHaveLength(1);expect(f.records.Sessions[0].notes).toBe('סיכום סינתטי');expect(f.requests.some(r=>r.path.includes('anonymize'))).toBe(false);expect(f.requests.some(r=>/web_workspace/.test(r.path))).toBe(false);await page.screenshot({path:info.outputPath('session.png'),fullPage:true});await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('עריכה נוספת סינתטית');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();expect(f.requests.filter(r=>r.path.endsWith('/save-session')&&r.body?.mode==='create')).toHaveLength(1);expect(f.requests.filter(r=>r.path.endsWith('/save-session')&&r.body?.mode==='update')).toHaveLength(1);
});
for(const type of ['diary_one','diary_two','diary_three'])test(`${type} edits either author in place and retries failure`,async({context,page})=>{
 const f=await fixture(context,{fail:true});await openEntry(page,type);const lead=page.locator('.ww-diary-section[data-part="event"] textarea').first();await lead.fill('טקסט סינתטי — מדויק!');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByRole('alert')).toBeVisible();await expect(lead).toHaveValue('טקסט סינתטי — מדויק!');await page.getByRole('button',{name:'ניסיון שמירה נוסף',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();const saves=f.requests.filter(r=>r.method==='PATCH');expect(saves).toHaveLength(2);expect(saves[1].body).not.toHaveProperty('created_by');expect(saves[1].body).not.toHaveProperty('patient_id');expect(f.requests.some(r=>r.path.includes('anonymize'))).toBe(false);expect(f.records[`${type}_entries`]).toHaveLength(1);
});
test('shared questionnaires never fetch/render/write notes; preserve bigint ID',async({context,page},info)=>{
 const f=await fixture(context);await openEntry(page,'questionnaire',true);await expect(page.locator('body')).not.toContainText('PRIVATE_NOTE_SENTINEL');await expect(page.locator('textarea')).toHaveCount(0);await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();expect(f.requests.filter(r=>r.path.endsWith('/load-questionnaires')).every(r=>r.body?.view==='shared')).toBe(true);expect(f.requests.some(r=>r.path.endsWith('/load-patients')||r.path.endsWith('/load-sessions'))).toBe(false);const saves=f.requests.filter(r=>r.path.endsWith('/save-questionnaire'));expect(saves).toHaveLength(1);expect(saves[0].body).not.toHaveProperty('combined_notes');expect(f.records.CombinedMood[0].combined_notes).toEqual({gad7:['PRIVATE_NOTE_SENTINEL'],phq9:[],interference:''});for(const r of f.requests){expect(r.path).not.toMatch(/Sessions|notifications|patient-names|messages/);expect(r.select).not.toMatch(/notes|formulation|\*/);}await expect(page.locator('.cb-header,.pw-picker')).toHaveCount(0);await expect(page.getByText('מטופל לדוגמה ב',{exact:true})).toHaveCount(0);await page.screenshot({path:info.outputPath('shared-questionnaire-bottom.png')});await page.evaluate(()=>window.scrollTo(0,0));await page.screenshot({path:info.outputPath('shared-questionnaire.png')});
});
test('dirty switching prompts; in-flight save cannot switch',async({context,page})=>{
 let release!:()=>void;const delay=new Promise<void>(r=>{release=r;});await fixture(context,{delay});await openEntry(page,'diary_one');await page.locator('[data-part="event"] textarea').fill('עריכה סינתטית');await page.getByLabel('מעבר למטופל/ת').selectOption(other);await expect(page.getByRole('dialog')).toBeVisible();await page.getByRole('dialog').getByRole('button').first().click();await expect(page).toHaveURL(new RegExp(patient));await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByRole('button',{name:'שומר…'})).toBeDisabled();await page.getByLabel('מעבר למטופל/ת').selectOption(other);await expect(page).toHaveURL(new RegExp(patient));release();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
});
test('uncertain create retains input and prevents automatic duplicate',async({context,page})=>{
 const f=await fixture(context,{uncertain:true});await page.goto(`/app/patients/${patient}/sessions`);await page.getByRole('button',{name:'פגישה חדשה',exact:true}).click();await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('סינתטי בלבד');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText(/לא ניתן לוודא אם הרשומה נשמרה/)).toBeVisible();await expect(page.getByRole('button',{name:'ניסיון שמירה נוסף',exact:true})).toBeDisabled();await expect(page.getByLabel('סיכום הפגישה',{exact:true})).toHaveValue('סינתטי בלבד');expect(f.requests.filter(r=>r.body?.mode==='create'&&r.path.endsWith('/save-session'))).toHaveLength(1);
});
test('single shared entry is isolated and exiting requires confirmation',async({context,page},info)=>{
 const f=await fixture(context);await page.goto(`/app/patients/${patient}/overview`);
 await expect(page.getByRole('button',{name:'תצוגה משותפת',exact:true})).toHaveCount(0);
 await page.getByRole('link',{name:'התחלת פגישה כעת',exact:true}).click();
 await expect(page).toHaveURL(new RegExp(`/shared/${patient}/questionnaire`));
 await expect(page.getByRole('heading',{name:'מטופלת לדוגמה א',exact:true})).toBeVisible();
 await expect(page.locator('.pw-tabs a')).toHaveCount(6);
 await expect(page.locator('.cb-header,.pw-picker')).toHaveCount(0);
 await expect(page.locator('body')).not.toContainText(user.email);
 await page.screenshot({path:info.outputPath('workspace.png'),fullPage:true});
 expect(f.requests.some(r=>r.path.endsWith('/save-session'))).toBe(false);
 await page.getByRole('link',{name:'יציאה לתיק הפרטי',exact:true}).click();
 await expect(page.getByRole('heading',{name:'חזרה לתיק הפרטי?'})).toBeVisible();
 await page.getByRole('dialog').getByRole('button').first().click();await expect(page.locator('.pw-shared')).toBeVisible();
 await page.getByRole('link',{name:'יציאה לתיק הפרטי',exact:true}).click();await page.getByRole('dialog').getByRole('button').last().click();
 await expect(page.locator('.pt')).toBeVisible();
});
test('unauthorized shared patient is neutral and never queries clinical tables',async({context,page})=>{const f=await fixture(context,{deny:true});await page.goto(`/app/shared/${patient}/diary_one`);await expect(page.getByRole('alert')).toBeVisible();expect(f.requests.some(r=>/diary_.*entries/.test(r.path))).toBe(false);await expect(page.locator('.pw-picker,.cb-header')).toHaveCount(0);});
for(const width of [1440,390])test(`RTL worksheet layout ${width}`,async({context,page},info)=>{await fixture(context);await page.setViewportSize({width,height:900});await openEntry(page,'diary_three');await expect(page.locator('.pw')).toHaveAttribute('dir','rtl');expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:info.outputPath(`patient-${width}.png`),fullPage:true});await page.evaluate(()=>document.documentElement.style.fontSize='24px');expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.keyboard.press('Tab');expect(await page.evaluate(()=>document.activeElement?.tagName)).not.toBe('BODY');});

test('shared new questionnaire completes scores and flags question nine without notes',async({context,page})=>{const f=await fixture(context);await page.goto(`/app/shared/${patient}/questionnaire`);await page.getByRole('button',{name:'שאלון חדש',exact:true}).click();await expect(page.getByText('השאלון טרם הושלם',{exact:false}).first()).toBeVisible();for(let i=0;i<16;i++)await page.locator('fieldset.ww-question').nth(i).getByRole('radio').nth(1).check();await page.locator('.ww-options-compact').getByRole('radio').nth(1).check();await expect(page.locator('.ww-safety')).toBeVisible();await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();const writes=f.requests.filter(r=>r.path.endsWith('/save-questionnaire')&&r.body?.mode==='create');expect(writes).toHaveLength(1);expect(writes[0].body).not.toHaveProperty('combined_notes');expect((writes[0].body?.changes as Record<string,unknown>).session_id).toBeNull();});

test('lost create response can recover by opening the confirmed row, then UPDATE',async({context,page})=>{const f=await fixture(context,{loseAfterSave:true});await page.goto(`/app/patients/${patient}/sessions`);await page.getByRole('button',{name:'פגישה חדשה',exact:true}).click();await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('טיוטה סינתטית');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText(/לא ניתן לוודא אם הרשומה נשמרה/)).toBeVisible();await page.getByRole('button',{name:'בדיקת ההיסטוריה',exact:true}).click();page.once('dialog',dialog=>dialog.accept());await page.locator('.pw-session-list button').first().click();await expect(page.getByText(/לא ניתן לוודא אם הרשומה נשמרה/)).toHaveCount(0);await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('עריכה סינתטית');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();expect(f.requests.filter(r=>r.path.endsWith('/save-session')&&r.body?.mode==='create')).toHaveLength(1);expect(f.requests.filter(r=>r.path.endsWith('/save-session')&&r.body?.mode==='update')).toHaveLength(1);});
test('search retains the selected patient identity',async({context,page})=>{await fixture(context);await page.goto(`/app/patients/${patient}/sessions`);await expect(page.getByRole('heading',{name:'מטופלת לדוגמה א'})).toBeVisible();await page.getByLabel('חיפוש מטופל/ת',{exact:true}).fill('לדוגמה ב');await expect(page.getByLabel('מעבר למטופל/ת')).toHaveValue(patient);await expect(page.getByLabel('מעבר למטופל/ת').locator('option:checked')).toHaveText('מטופלת לדוגמה א');});

for(const width of [1440,800,390])test(`contextual record lists ${width}`,async({context,page},info)=>{
 const f=await fixture(context);await page.setViewportSize({width,height:900});
 f.records.Sessions=[{id:'s1',patient_id:patient,session_date:'2026-10-30',type:'intake',notes:'סיכום סינתטי לדוגמה. זוהי תצוגה מקדימה של הפגישה, לפתיחת הסיכום המלא בוחרים בשורה.'},{id:'s2',patient_id:patient,session_date:'2026-10-20',type:'',notes:''}];
 f.records.CombinedMood.push({...f.records.CombinedMood[0],id:'q2',answered_date:'2026-10-22',gad7_answers:[1,null],phq9_answers:[0,1],session_id:'s1'});
 for(const route of ['','sessions','questionnaire','diary_three']){
  await page.goto(route?`/app/patients/${patient}/${route}`:'/app/');await expect(page.locator('.pw-record-list').first()).toBeVisible();
  await expect(page.locator('.pw-record-list>li').first()).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:info.outputPath(`${route||'patients'}-${width}.png`),fullPage:true});
  if(route==='questionnaire'){await expect(page.getByText('תשובות · טרם הושלם')).toHaveCount(2);await expect(page.locator('.pw-list-scores').first()).toContainText('7');}
 }
 await page.goto('/app/');await page.getByLabel('חיפוש מטופל/ת',{exact:true}).fill('אין התאמה');await expect(page.getByText('לא נמצאו מטופלים בחיפוש זה.')).toBeVisible();
});
test('visible intensity controls preserve null, keyboard values and before/after serialization',async({context,page},info)=>{
 const f=await fixture(context);f.records.diary_three_entries[0].feelings=[{name:'עצב',intensityBefore:null,intensityAfter:null}];
 await openEntry(page,'diary_three');await page.getByRole('button',{name:'היומן המלא',exact:true}).click();
 const before=page.getByRole('slider',{name:'עוצמה לפני — עצב — מחוון',exact:true});
 const number=page.getByRole('spinbutton',{name:'עוצמה לפני — עצב — אחוז',exact:true});
 await expect(before).toBeVisible();await expect(number).toHaveValue('');await expect(before).toHaveAttribute('aria-valuetext','טרם נבחרה עוצמה');
 await before.focus();await page.keyboard.press('Home');await expect(number).toHaveValue('0');await page.keyboard.press('ArrowLeft');await expect(number).toHaveValue('1');
 await expect(before).toHaveAttribute('dir','rtl');
 const track=await before.boundingBox();await before.click({position:{x:track!.width-2,y:track!.height/2}});await expect(number).toHaveValue('0');
 await number.fill('73');await expect(before).toHaveValue('73');
 const after=page.getByRole('spinbutton',{name:'עוצמה אחרי — עצב — אחוז',exact:true});await after.fill('25');await expect(number).toHaveValue('73');
 await page.screenshot({path:info.outputPath('intensity-desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});await expect(number).toHaveValue('73');await expect(after).toHaveValue('25');
 await page.locator('[data-part="feeling"]').first().scrollIntoViewIfNeeded();
 await page.screenshot({path:info.outputPath('intensity-mobile.png')});
 await page.locator('[data-part="feeling"]').last().scrollIntoViewIfNeeded();
 await page.screenshot({path:info.outputPath('intensity-mobile-after.png')});
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
 expect(f.records.diary_three_entries[0].feelings).toEqual([{name:'עצב',intensityBefore:73,intensityAfter:25}]);
 expect(f.requests.some(r=>r.path.includes('anonymize'))).toBe(false);
});

for(const width of [1440,390])test(`focused editors cancel and preserve list ${width}`,async({context,page},info)=>{
 const f=await fixture(context);f.records.Sessions=[{id:'s1',patient_id:patient,session_date:'2026-10-30',type:'intake',notes:'סיכום לדוגמה בלבד'}];await page.setViewportSize({width,height:900});
 await page.goto(`/app/patients/${patient}/sessions`);await page.getByRole('button',{name:'פגישה חדשה',exact:true}).click();
 const dialog=page.getByRole('dialog',{name:'פגישה חדשה',exact:true});await expect(dialog).toBeVisible();await expect(page.locator('.pw-session-list li')).toHaveCount(1);
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).waitFor({state:'visible'});
 await page.screenshot({path:info.outputPath(`session-dialog-${width}.png`)});
 await dialog.getByRole('button',{name:'ביטול',exact:true}).click();await expect(dialog).toHaveCount(0);await expect(page.getByRole('button',{name:'פגישה חדשה',exact:true})).toBeFocused();
 await page.getByRole('button',{name:'פגישה חדשה',exact:true}).click();await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('טיוטה סינתטית');page.once('dialog',d=>d.dismiss());await page.keyboard.press('Escape');await expect(dialog).toBeVisible();await expect(page.getByLabel('סיכום הפגישה',{exact:true})).toHaveValue('טיוטה סינתטית');
 page.once('dialog',d=>d.accept());await dialog.getByRole('button',{name:'ביטול',exact:true}).click();await expect(dialog).toHaveCount(0);expect(f.requests.filter(r=>r.path.endsWith('/save-session')&&r.body?.mode==='create')).toHaveLength(0);
 await openEntry(page,'questionnaire');const q=page.getByRole('dialog',{name:'עריכת שאלון',exact:true});await expect(q).toBeVisible();await page.screenshot({path:info.outputPath(`questionnaire-dialog-${width}.png`)});
 await q.getByRole('button',{name:'חזרה לשאלונים',exact:true}).click();await expect(q).toHaveCount(0);await expect(page.locator('.pw-history button').first()).toBeFocused();
 await page.locator('.pw-history button').first().click();await page.locator('fieldset.ww-question').first().getByRole('radio').nth(2).check();page.once('dialog',d=>d.dismiss());await q.getByRole('button',{name:'חזרה לשאלונים',exact:true}).click();await expect(q).toBeVisible();await expect(page.locator('fieldset.ww-question').first().getByRole('radio').nth(2)).toBeChecked();
 page.once('dialog',d=>d.accept());await page.keyboard.press('Escape');await expect(q).toHaveCount(0);expect(f.requests.filter(r=>r.method==='PATCH')).toHaveLength(0);
});
test('session modal cannot dismiss while saving',async({context,page})=>{
 let release!:()=>void;await fixture(context,{delay:new Promise<void>(r=>release=r)});await page.goto(`/app/patients/${patient}/sessions`);await page.getByRole('button',{name:'פגישה חדשה',exact:true}).click();await page.locator('.pw-session-editor select').selectOption('intake');await page.getByLabel('סיכום הפגישה',{exact:true}).fill('סינתטי');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByRole('button',{name:'ביטול',exact:true})).toBeDisabled();await page.keyboard.press('Escape');await expect(page.getByRole('dialog')).toBeVisible();release();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();await page.getByRole('button',{name:'חזרה לפגישות',exact:true}).click();await expect(page.getByRole('dialog')).toHaveCount(0);await expect(page.locator('.pw-session-list li')).toHaveCount(1);
});

for(const type of ['diary_one','diary_two','diary_three'])test(`guided diary navigation preserves edits ${type}`,async({context,page},info)=>{
 const f=await fixture(context);await page.setViewportSize({width:390,height:844});await openEntry(page,type);
 await expect(page.locator('.ww-diary-section')).toHaveCount(1);
 await expect(page.getByRole('button',{name:'הקודם',exact:true})).toBeDisabled();
 await page.locator('[data-part="event"] textarea').fill('תוכן סינתטי שנשמר בין חלקים');
 await page.getByRole('button',{name:'הבא',exact:true}).click();await expect(page.locator('[data-part="thought"] textarea')).toHaveValue('מחשבה סינתטית');
 await page.locator('[data-part="thought"] textarea').fill('מחשבה סינתטית מעודכנת');
 await page.getByRole('button',{name:'הקודם',exact:true}).click();await expect(page.locator('[data-part="event"] textarea')).toHaveValue('תוכן סינתטי שנשמר בין חלקים');
 await page.getByLabel('מעבר לחלק',{exact:true}).selectOption('2');await expect(page.getByRole('slider').first()).toBeVisible();
 await page.screenshot({path:info.outputPath(`${type}-phone-focus.png`)});
 await page.getByRole('button',{name:'היומן המלא',exact:true}).click();await expect(page.locator('.ww-diary-section')).toHaveCount(type==='diary_one'?4:type==='diary_two'?5:7);
 await expect(page.locator('[data-part="thought"] textarea')).toHaveValue('מחשבה סינתטית מעודכנת');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:info.outputPath(`${type}-phone-all.png`),fullPage:true});
 await page.setViewportSize({width:1440,height:1000});await page.screenshot({path:info.outputPath(`${type}-desktop-all.png`),fullPage:true});
 await page.getByRole('button',{name:'חלק אחד',exact:true}).click();await expect(page.getByLabel('מעבר לחלק',{exact:true})).toHaveValue('2');
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
 expect(f.records[`${type}_entries`][0][type==='diary_three'?'situation':'event']).toBe('תוכן סינתטי שנשמר בין חלקים');
});
for(const chosen of ['questionnaire','diary_one','diary_two','diary_three'])test(`shared tools and history scope ${chosen}`,async({context,page})=>{
 const f=await fixture(context);await page.goto(`/app/shared/${patient}/${chosen}?form=diary_one`);
 await expect(page.locator('.pw-tabs a')).toHaveCount(6);
 await page.locator('.pw-history button').first().click();
 await expect(page.locator('body')).not.toContainText('PRIVATE_NOTE_SENTINEL');
 expect(f.requests.some(r=>r.path.endsWith('/load-sessions')||r.path.endsWith('/load-patients')||r.path.endsWith('/patient-names'))).toBe(false);
 expect(f.requests.filter(r=>r.path.endsWith('/load-questionnaires')).every(r=>r.body?.view==='shared')).toBe(true);
 for(const r of f.requests.filter(r=>/diary_.*entries/.test(r.path)))expect(r.patient).toBe(`eq.${patient}`);
 await page.reload();await expect(page.locator('.pw-tabs a')).toHaveCount(6);
});

for(const width of [1280,1440])test(`laptop presentation remains legible when screen-shared ${width}`,async({context,page},info)=>{
 const f=await fixture(context);await page.setViewportSize({width,height:width===1280?800:900});
 await openEntry(page,'diary_three',true);
 const text=page.locator('[data-part="event"] textarea');
 await text.fill('כשלא קיבלתי תשובה להודעה, חשבתי שעשיתי משהו לא בסדר.');
 await expect(page.locator('.diary-presentation')).toBeVisible();
 const font=await text.evaluate(e=>parseFloat(getComputedStyle(e).fontSize));expect(font/width).toBeGreaterThan(.04);
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.evaluate(()=>window.scrollTo(0,0));
 const sharedImage=await page.screenshot({path:info.outputPath(`laptop-${width}-event.png`)});
 await page.getByRole('button',{name:'הגדלת טקסט בשיתוף',exact:true}).click();expect(await text.evaluate(e=>parseFloat(getComputedStyle(e).fontSize))).toBeGreaterThan(font);
 await page.getByRole('button',{name:'הקטנת טקסט בשיתוף',exact:true}).click();
 await page.getByRole('button',{name:'הבא',exact:true}).click();await expect(page.locator('.ww-diary-section:visible')).toHaveCount(1);
 await page.screenshot({path:info.outputPath(`laptop-${width}-thought.png`)});
 await page.getByLabel('מעבר לחלק',{exact:true}).selectOption('2');await page.screenshot({path:info.outputPath(`laptop-${width}-feelings.png`)});
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();await expect(page.locator('.ww-diary-section')).toHaveCount(7);
 await page.evaluate(()=>window.scrollTo(0,0));
 const overviewImage=await page.screenshot({path:info.outputPath(`laptop-${width}-overview.png`)});
 expect(await text.evaluate(e=>parseFloat(getComputedStyle(e).fontSize))).toBeGreaterThanOrEqual(18);
 const panels=await page.locator('.diary-flow-panel').evaluateAll(elements=>elements.map(e=>e.getBoundingClientRect().top));expect(new Set(panels).size).toBe(1);
 await page.getByRole('button',{name:'תצוגה ממוקדת',exact:true}).click();await expect(page.getByLabel('מעבר לחלק',{exact:true})).toHaveValue('2');
 await page.getByLabel('מעבר לחלק',{exact:true}).selectOption('0');await expect(text).toHaveValue('כשלא קיבלתי תשובה להודעה, חשבתי שעשיתי משהו לא בסדר.');
 await page.getByRole('button',{name:'מסך מלא',exact:true}).click();await expect(page.locator('.pw-shared')).toHaveJSProperty('nodeName','MAIN');
 await expect.poll(()=>page.evaluate(()=>!!document.fullscreenElement)).toBe(true);
 await page.getByRole('button',{name:'מסך מלא',exact:true}).click();await expect.poll(()=>page.evaluate(()=>!!document.fullscreenElement)).toBe(false);
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
 expect(f.records.diary_three_entries[0].situation).toBe('כשלא קיבלתי תשובה להודעה, חשבתי שעשיתי משהו לא בסדר.');
 const viewer=await context.newPage();
 for(const received of [{width:390,height:844,name:'portrait'},{width:844,height:390,name:'landscape'}]){
  await viewer.setViewportSize(received);
  await viewer.setContent(`<html><body style="margin:0;background:#14171d;display:grid;place-items:center;height:100vh"><img alt="הדמיית חלון המחשב המשותף מוקטן למסך טלפון" style="display:block;max-width:100vw;max-height:100vh;object-fit:contain" src="data:image/png;base64,${sharedImage.toString('base64')}"></body></html>`);
  await viewer.locator('img').evaluate(async image=>{await (image as HTMLImageElement).decode();});
  await viewer.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await viewer.screenshot({path:info.outputPath(`received-${width}-${received.name}.png`)});
  await viewer.locator('img').evaluate((image,src)=>{(image as HTMLImageElement).src=src;},`data:image/png;base64,${overviewImage.toString('base64')}`);
  await viewer.locator('img').evaluate(async image=>{await (image as HTMLImageElement).decode();});
  await viewer.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await viewer.screenshot({path:info.outputPath(`received-overview-${width}-${received.name}.png`)});
 }
 await viewer.close();
});

test('names start with directory, cold picker waits and reopening reuses names',async({context,page})=>{
 let release!:()=>void;const delay=new Promise<void>(resolve=>release=resolve);
 const f=await fixture(context,{nameDelay:delay});await page.goto('/app/');
 await expect.poll(()=>f.requests.filter(r=>r.path.endsWith('/patient-names')).length).toBe(1);
 await expect.poll(()=>f.requests.filter(r=>r.path.endsWith('/load-patients')).length).toBe(1);
 await expect(page.locator('.pw-picker select')).toBeDisabled();
 await expect(page.locator('.pw-directory .pw-patient-row')).toHaveCount(0);
 await expect(page.locator('body')).not.toContainText('מטופל/ת ללא שם');
 await page.getByRole('searchbox').fill('לדוגמה א');release();
 await expect(page.getByRole('link',{name:/מטופלת לדוגמה א/})).toBeVisible();
 await expect(page.getByRole('link',{name:/מטופל לדוגמה ב/})).toHaveCount(0);
 await page.getByRole('link',{name:/מטופלת לדוגמה א/}).click();
 await expect(page.getByRole('heading',{name:'מטופלת לדוגמה א'})).toBeVisible();
 await page.getByRole('link',{name:'כל המטופלים',exact:true}).click();
 await expect(page.getByRole('link',{name:/מטופלת לדוגמה א/})).toBeVisible();
 expect(f.requests.filter(r=>r.path.endsWith('/patient-names'))).toHaveLength(1);
 expect(await page.evaluate(()=>Object.keys(localStorage).some(k=>k.startsWith('cbtipul.names.')))).toBe(false);
});
test('a confirmed missing name differs from a failed lookup',async({context,page})=>{
 await fixture(context,{missingName:true});await page.goto('/app/');
 await expect(page.getByRole('link',{name:/מטופל\/ת ללא שם/})).toBeVisible();
});
test('failed names never render unnamed directory rows',async({context,page})=>{
 await fixture(context,{nameFailure:true});await page.goto('/app/');
 await expect(page.locator('.pw-picker select')).toBeDisabled();
 await expect(page.getByRole('option',{name:'טעינת השמות נכשלה'})).toBeAttached();
 await expect(page.locator('.pw-directory .pw-patient-row')).toHaveCount(0);
});

test('patient brand guide: responsive navigation and record presentation',async({context,page},info)=>{
 const f=await fixture(context);
 f.records.Sessions=[{id:'session-guide',patient_id:patient,session_date:'2026-11-16',type:'intake',notes:'סיכום לדוגמה בלבד. בפגישה שוחחנו על מטרות הטיפול ועל הצעדים לקראת הפגישה הבאה.'}];
 for(const width of [1440,390]){
  await page.setViewportSize({width,height:900});
  for(const section of ['sessions','questionnaire','diary_one']){
   await page.goto(`/app/patients/${patient}/${section}`);
   await expect(page.getByRole('heading',{name:'מטופלת לדוגמה א',exact:true})).toBeVisible();
   await expect(page.locator('.pw-record-list')).toBeVisible();
   await page.evaluate(()=>document.fonts.ready);
   await page.addStyleTag({content:"*,*::before,*::after{transition:none!important;animation:none!important}"});
   expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
   await page.screenshot({path:info.outputPath(`guide-${section}-${width}.png`),fullPage:true});
  }
 }
 await page.getByRole('link',{name:'פגישות',exact:true}).click();
 await page.getByRole('button',{name:'פגישה חדשה',exact:true}).click();
 await expect(page.getByRole('dialog')).toBeVisible();
 await page.getByRole('button',{name:'ביטול',exact:true}).click();
 await expect(page.getByRole('dialog')).toHaveCount(0);
});

test('patient guide uses exact entity and severity fills, including incomplete scores',async({context,page})=>{
 const f=await fixture(context);
 f.records.CombinedMood=[0,1,2,3,null].map((answer,i)=>({id:String(i+1),patient_id:patient,answered_date:'2026-11-18',gad7_answers:Array(7).fill(answer),phq9_answers:Array(9).fill(answer),created_by:'therapist'}));
 await page.goto(`/app/patients/${patient}/questionnaire`);
 const rows=page.locator('.pw-questionnaire-row');
 await expect(rows).toHaveCount(5);
 await expect(rows.first()).toHaveCSS('background-color','rgb(216, 254, 245)');
 await rows.first().hover();
 await expect(rows.first()).toHaveCSS('background-color','rgb(216, 254, 245)');
 const fills=['rgb(185, 255, 239)','rgb(255, 197, 22)','rgb(255, 156, 69)','rgb(251, 81, 58)','rgb(232, 240, 248)'];
 for(let i=0;i<5;i++)await expect(rows.nth(i).locator('.pw-list-scores>span').first()).toHaveCSS('background-color',fills[i]);
 await expect(rows.last()).toContainText('טרם הושלם');
 await expect(page.locator('.cb-header')).toHaveCSS('font-family','Rubik, system-ui, sans-serif');
 await expect(page.locator('.pw-list-flag').first()).toHaveCSS('background-color','rgb(251, 81, 58)');
 await page.getByRole('link',{name:'יומן מחשבות 1',exact:true}).click();
 await expect(page.locator('.pw-diary-row').first()).toHaveCSS('background-color','rgb(255, 245, 213)');
});

test('source-matched patient overview: calendar, weekly columns, filters and record actions',async({context,page},info)=>{
 const f=await fixture(context);
 const now=new Date(), day=`${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-10`;
 f.records.Sessions=[{id:'overview-session',patient_id:patient,session_date:day,type:'intake',notes:'סיכום סינתטי לבדיקה בלבד'}];
 f.records.CombinedMood[0].answered_date=day;
 for(const type of ['diary_one','diary_two','diary_three']) f.records[type+'_entries'][0].created_at=day+'T12:00:00Z';
 await page.setViewportSize({width:1440,height:1000});
 await page.goto(`/app/patients/${patient}/overview`);
 await expect(page.getByRole('button',{name:'רשימה',exact:true})).toHaveAttribute('aria-pressed','true');
 await expect(page.locator('.pt-week-columns .pt-entry')).toHaveCount(6);
 await page.getByRole('button',{name:'לוח שנה',exact:true}).click();
 await expect(page.locator('.pt-day .pt-entry')).toHaveCount(6);
 await expect(page.getByRole('heading',{name:'מטופלת לדוגמה א',exact:true})).toBeVisible();
 await page.evaluate(()=>document.fonts.ready);
 await page.screenshot({path:info.outputPath('overview-calendar-desktop.png'),fullPage:true});
 await page.getByRole('button',{name:'שאלונים',exact:true}).click();
 await expect(page.locator('.pt-day .pt-entry')).toHaveCount(2);
 await page.getByRole('button',{name:'הכל',exact:true}).click();
 await page.getByRole('button',{name:'רשימה',exact:true}).click();
 await expect(page.locator('.pt-week-columns .pt-entry')).toHaveCount(6);
 await expect(page.locator('.pt-toolbar')).toHaveCount(0);
 // Within each week, entries share a horizontal RTL row inside their category.
 for (const kind of ['questionnaire','diary']) {
  const cards=await page.locator(`.pt-week-column > .pt-entry[data-kind="${kind}"]`).evaluateAll(nodes=>nodes.map(node=>{
   const {x,y,width}=node.getBoundingClientRect();return {x,y,width};
  }));
  expect(cards.length).toBeGreaterThan(1);
  for(let index=1;index<cards.length;index++) {
   expect(Math.abs(cards[index].y-cards[0].y)).toBeLessThan(1);
   expect(cards[index].x+cards[index].width).toBeLessThan(cards[index-1].x);
  }
 }
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.locator('.pt-diary-add summary').click();
 await expect(page.locator('.pt-diary-add').getByRole('link',{name:'יומן מחשבות 3',exact:true})).toBeVisible();
 await page.locator('.pt-diary-add summary').click();
 await page.mouse.move(0,0);
 await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
 await page.screenshot({path:info.outputPath('overview-list-desktop.png'),fullPage:true,animations:'disabled'});
 await page.setViewportSize({width:390,height:844});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.locator('.pt-mobile-add summary').click();
 await expect(page.locator('.pt-mobile-add').getByRole('link',{name:'שאלון חדש',exact:true})).toBeVisible();
 await page.locator('.pt-mobile-add summary').click();
 await expect(page.locator('.pt')).toHaveCount(1);
 await expect(page.locator('.cb-header')).toHaveCount(1);
 await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
 await page.screenshot({path:info.outputPath('overview-list-phone.png'),animations:'disabled'});
 await page.locator('.pt-week-columns .pt-entry').last().scrollIntoViewIfNeeded();
 await page.screenshot({path:info.outputPath('overview-list-phone-lower.png'),animations:'disabled'});
 await page.locator('.pt-entry[data-kind="questionnaire"]').first().click();
 await expect(page.getByRole('dialog')).toBeVisible();
 await page.getByRole('button',{name:'חזרה לשאלונים',exact:true}).click();
 await page.getByRole('link',{name:'התיק הטיפולי',exact:true}).click();
 await page.getByRole('link',{name:'התחלת פגישה כעת',exact:true}).click();
 await expect(page.locator('.pw-shared')).toBeVisible();
 expect(f.requests.some(r=>r.path.endsWith('/save-session'))).toBe(false);
 await page.getByRole('link',{name:'יציאה לתיק הפרטי',exact:true}).click();
 await page.getByRole('dialog').getByRole('button').last().click();
 await page.getByRole('button',{name:'רשימה',exact:true}).click();
 await page.locator('.pt-entry[data-kind="session"]').first().click();
 await expect(page.getByLabel('סיכום הפגישה',{exact:true})).toHaveValue('סיכום סינתטי לבדיקה בלבד');
});

for(const type of ['diary_one','diary_two','diary_three'])test(`shared redesign states ${type}`,async({context,page},info)=>{
 const f=await fixture(context,{fail:true});await page.setViewportSize({width:1366,height:768});
 await page.goto(`/app/shared/${patient}/${type}`);
 await page.getByRole('button',{name:'רשומה חדשה',exact:true}).click();
 await expect(page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true})).toBeDisabled();
 const event=page.locator('[data-part="event"] textarea');
 await event.fill('טיוטה חלקית סינתטית');
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();await expect(event).toHaveValue('טיוטה חלקית סינתטית');
 await page.screenshot({path:info.outputPath(`${type}-partial.png`),fullPage:true});
 // History cannot replace an unsaved draft without an explicit discard.
 await page.getByRole('button',{name:'היסטוריה',exact:true}).click();page.once('dialog',d=>d.dismiss());
 await page.locator('.pw-history button').first().click();await expect(event).toHaveValue('טיוטה חלקית סינתטית');
 page.once('dialog',d=>d.accept());await page.locator('.pw-history button').first().click();
 await expect(event).toHaveValue('אירוע סינתטי');
 const long='תיאור סינתטי בלבד: בזמן השיחה חשבתי שלא מבינים אותי, והרגשתי עצב. '.repeat(8);
 await event.fill(long);
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();
 await expect(page.locator('.diary-flow-panel:visible')).toHaveCount(type==='diary_one'?4:type==='diary_two'?5:7);
 await page.screenshot({path:info.outputPath(`${type}-overview.png`),fullPage:true});
 await page.getByRole('button',{name:'התמקדות בחלק',exact:true}).nth(1).click();
 await expect(page.locator('[data-part="thought"] h2')).toBeFocused();
 await page.getByRole('button',{name:'הקודם',exact:true}).click();await expect(event).toHaveValue(long);
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();await expect(page.getByRole('alert')).toBeVisible();
 await expect(event).toHaveValue(long);await page.screenshot({path:info.outputPath(`${type}-error.png`),fullPage:true});
 await page.getByRole('button',{name:'ניסיון שמירה נוסף',exact:true}).click();await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();await expect(event).toHaveValue(long);
 expect(f.records[type+'_entries']).toHaveLength(1);
 await page.setViewportSize({width:390,height:844});
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:info.outputPath(`${type}-phone.png`),fullPage:true});
});

test('shared new diary saves once, keeps mode and protects tab navigation',async({context,page})=>{
 const f=await fixture(context);await page.goto(`/app/shared/${patient}/diary_one`);
 await page.getByRole('button',{name:'רשומה חדשה',exact:true}).click();
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();
 await page.locator('[data-part="event"] textarea').fill('אירוע חדש סינתטי');
 await page.locator('[data-part="thought"] textarea').fill('מחשבה חדשה סינתטית');
 await page.locator('[data-part="behaviour"] textarea').first().fill('פעולה סינתטית');
 await page.getByRole('button',{name:'הוספת רגש',exact:true}).click();
 await page.locator('.ww-feeling-picker:popover-open').getByRole('button',{name:'עצוב',exact:true}).click();
 await page.locator('.pw-tabs').getByRole('link',{name:'שאלונים',exact:true}).click();
 await expect(page.getByRole('dialog')).toBeVisible();await page.getByRole('dialog').getByRole('button').first().click();
 await expect(page.locator('[data-part="event"] textarea')).toHaveValue('אירוע חדש סינתטי');
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();
 await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
 await expect(page.getByRole('button',{name:'תצוגה מלאה',exact:true})).toHaveAttribute('aria-pressed','true');
 await page.locator('[data-part="event"] textarea').fill('אירוע חדש סינתטי — תיקון');
 await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();
 await expect(page.getByText('הרשומה נשמרה בתיק המטופל/ת',{exact:true})).toBeVisible();
 expect(f.requests.filter(r=>r.path.endsWith('/diary_one_entries')&&r.method==='POST')).toHaveLength(1);
 expect(f.requests.filter(r=>r.path.endsWith('/diary_one_entries')&&r.method==='PATCH')).toHaveLength(1);
});

test('shared patient-authored questionnaire remains read-only',async({context,page})=>{
 const f=await fixture(context);f.records.CombinedMood[0].created_by='patient';
 await openEntry(page,'questionnaire',true);
 await expect(page.getByText('לצפייה בלבד',{exact:true})).toBeVisible();
 await expect(page.getByRole('radio').first()).toBeDisabled();
 await expect(page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true})).toBeDisabled();
 expect(f.requests.some(r=>r.path.endsWith('/save-questionnaire'))).toBe(false);
});

for(const failure of [false,true])test(`shared exit guard covers pending and failed access ${failure}`,async({context,page})=>{
 await fixture(context);await page.goto(`/app/patients/${patient}/overview`);
 await expect(page.locator('.pt')).toBeVisible();
 let release!:()=>void;const wait=new Promise<void>(r=>release=r);
 await context.route('**/rest/v1/Patients?**',async route=>{
  if(new URL(route.request().url()).searchParams.get('select')!=='id')return route.fallback();
  await wait;await route.fulfill({status:failure?403:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(failure?{code:'42501'}:{id:patient})});
 });
 await page.getByRole('link',{name:'התחלת פגישה כעת',exact:true}).click();
 await page.getByRole('link',{name:'יציאה לתיק הפרטי',exact:true}).click();
 await expect(page.getByRole('heading',{name:'חזרה לתיק הפרטי?'})).toBeVisible();
 await expect(page.locator('.pt,.cb-header')).toHaveCount(0);
 await page.getByRole('dialog').getByRole('button').first().click();release();
 if(failure)await expect(page.getByRole('alert')).toBeVisible();else await expect(page.locator('.pw-history')).toBeVisible();
 await page.evaluate(()=>history.back());
 await expect(page.getByRole('heading',{name:'חזרה לתיק הפרטי?'})).toBeVisible();
 await expect(page.locator('.pt,.cb-header')).toHaveCount(0);
 await page.getByRole('dialog').getByRole('button').last().click();await expect(page.locator('.pt')).toBeVisible();
});

for(const type of ['diary_two','diary_three'])test(`thinking errors and alternatives show current automatic thoughts ${type}`,async({context,page},info)=>{
 await fixture(context);await openEntry(page,type,true);
 await page.getByLabel('מעבר לחלק',{exact:true}).selectOption('1');
 await page.locator('[data-part="thought"] textarea').fill('מחשבה מקורית לצורך בדיקה');
 await page.getByLabel('מעבר לחלק',{exact:true}).selectOption('3');
 await expect(page.locator('[data-part=examine] .ww-thought-reference')).toBeVisible();
 await expect(page.locator('[data-part=examine] .ww-thought-reference')).toContainText('מחשבה מקורית לצורך בדיקה');
 await page.getByLabel('מעבר לחלק',{exact:true}).selectOption('4');
 await expect(page.getByRole('complementary',{name:'המחשבות האוטומטיות'})).toContainText('מחשבה מקורית לצורך בדיקה');
 await page.locator('[data-part="alternative"] textarea').fill('אפשרות אחרת');
 await page.screenshot({path:info.outputPath(`${type}-alternative-context.png`)});
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();
 await expect(page.locator('[data-part="alternative"] textarea')).toHaveValue('אפשרות אחרת');
 await expect(page.locator('[data-part="thought"] textarea')).toHaveValue('מחשבה מקורית לצורך בדיקה');
});

test('conceptualization saved draft, publication, conflict and shared privacy',async({context,page},info)=>{
 const f=await fixture(context);
 let current:Record<string,unknown>={patient_id:patient,document:null,revision:null,published_revision:null,published_at:null,updated_at:null};let sent:unknown=null;let serial=0;
 const calls:Record<string,unknown>[]=[];
 await context.route('**/functions/v1/patient-conceptualization',async route=>{
  const body=route.request().postDataJSON();calls.push(body);
  if(body.action==='load_draft')return route.fulfill({json:current});
  if(body.expected_revision!==current.revision)return route.fulfill({status:409,json:{error:'revision_conflict'}});
  if(body.action==='save')current={...current,document:structuredClone(body.document),revision:`opaque-${++serial}`,updated_at:'2026-11-20T12:00:00Z'};
  if(body.action==='publish'){sent=structuredClone(current.document);current={...current,published_revision:current.revision,published_at:'2026-11-20T12:00:00Z'};}
  return route.fulfill({json:current});
 });
 await page.goto(`/app/shared/${patient}/conceptualization`);
 await expect(page.getByRole('heading',{name:'המשגה',exact:true})).toBeVisible();
 await page.getByRole('button',{name:'יצירת המשגה',exact:true}).click();await page.locator('.concept-section').first().getByRole('button',{name:'הוספת משפט'}).click();
 await page.getByLabel('חוויות ילדות 1',{exact:true}).fill('A — משפט סינתטי');
 await expect(page.getByRole('button',{name:'שליחה למטופל/ת',exact:true})).toBeDisabled();
 await page.getByRole('button',{name:'שמירה',exact:true}).click();await expect(page.getByText('ההמשגה נשמרה',{exact:true})).toBeVisible();
 expect(sent).toBeNull();expect(calls.find(c=>c.action==='save')?.expected_revision).toBeNull();
 await page.getByRole('button',{name:'שליחה למטופל/ת',exact:true}).click();await expect(page.getByText('ההמשגה נשלחה למטופל/ת',{exact:true})).toBeVisible();
 const a=structuredClone(sent);
 const second=await context.newPage();await second.goto(`/app/shared/${patient}/conceptualization`);
 await second.getByRole('button',{name:'עריכה',exact:true}).click();await second.getByLabel('חוויות ילדות 1',{exact:true}).fill('B — משפט סינתטי');await second.getByRole('button',{name:'שמירה',exact:true}).click();await expect(second.getByText('ההמשגה נשמרה',{exact:true})).toBeVisible();expect(sent).toEqual(a);
 await page.getByRole('button',{name:'שליחה למטופל/ת',exact:true}).click();await expect(page.getByRole('alert')).toContainText('השתנתה במכשיר אחר');expect(sent).toEqual(a);
 await page.getByRole('button',{name:'עריכה',exact:true}).click();await page.getByLabel('חוויות ילדות 1',{exact:true}).fill('עריכה מקומית שלא תימחק');
 await page.getByRole('button',{name:'שמירה',exact:true}).click();await expect(page.getByRole('alert')).toBeVisible();await expect(page.getByLabel('חוויות ילדות 1',{exact:true})).toHaveValue('עריכה מקומית שלא תימחק');
 page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'טעינת הגרסה העדכנית',exact:true}).click();await expect(page.locator('.concept-reading')).toContainText('B — משפט סינתטי');
 await page.getByRole('button',{name:'חזרה לשינויים שלי',exact:true}).click();await expect(page.getByLabel('חוויות ילדות 1',{exact:true})).toHaveValue('עריכה מקומית שלא תימחק');
 await second.getByRole('button',{name:'שליחה למטופל/ת',exact:true}).click();await expect(second.getByText('ההמשגה נשלחה למטופל/ת',{exact:true})).toBeVisible();expect(sent).toEqual(current.document);expect(sent).not.toEqual(a);
 expect(f.requests.some(r=>r.path.endsWith('/load-sessions')||r.path.endsWith('/load-patients')||r.path.endsWith('/patient-names'))).toBe(false);
 await expect(page.getByText('PRIVATE_NOTE_SENTINEL')).toHaveCount(0);await expect(page.locator('.cb-header,.pw-picker')).toHaveCount(0);
 await second.screenshot({path:info.outputPath('conceptualization-shared.png'),fullPage:true});
 await second.setViewportSize({width:390,height:844});
 await expect(second.getByRole('button',{name:'שליחה למטופל/ת',exact:true})).toBeVisible();
 expect(await second.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
 await second.screenshot({path:info.outputPath('conceptualization-narrow.png'),fullPage:true});await second.close();
});

const conceptKeys=['childhood_experiences','core_beliefs','assumptions','rules','biased_expectations'];
async function conceptFixture(context:BrowserContext){
 const f=await fixture(context);const document=Object.fromEntries(conceptKeys.map(k=>[k,k==='core_beliefs'?['משפט קיים']:[]]));
 await context.route('**/functions/v1/patient-conceptualization',r=>r.fulfill({json:{patient_id:patient,document,revision:'v1',published_revision:null,published_at:null}}));return f;
}
for(const [index,key] of conceptKeys.entries())test(`concept AI section ${key} appends without saving`,async({context,page},info)=>{
 const f=await conceptFixture(context);let request:Record<string,unknown>|null=null;
 await context.route('**/functions/v1/suggest-conceptualization-section',r=>{request=r.request().postDataJSON();return r.fulfill({json:{suggestions:['הצעה סינתטית ראשונה','הצעה סינתטית שנייה']}});});
 await page.goto(`/app/patients/${patient}/conceptualization`);await page.getByRole('button',{name:'עריכה',exact:true}).click();
 const section=page.locator('.concept-section').nth(index);
 await page.getByLabel('אמונת יסוד 1',{exact:true}).fill('עריכה שטרם נשמרה');
 await section.getByRole('button',{name:'הצעות AI',exact:true}).click();
 await expect(section.getByText('הצעה סינתטית ראשונה',{exact:true})).toBeVisible();
 expect(request!.patient_id).toBe(patient);expect(request!.section).toBe(key);expect(request!.document).toMatchObject({core_beliefs:['עריכה שטרם נשמרה']});expect(Object.keys(request!.document as object)).toHaveLength(5);expect(typeof request!.patient_context).toBe('string');
 await section.getByRole('checkbox').first().check();await section.getByRole('checkbox').last().check();await section.getByRole('button',{name:'הוספת הנבחרות'}).click();
 const fields=section.locator('textarea');await expect(fields).toHaveCount(key==='core_beliefs'?3:2);await fields.last().fill('הצעה שנערכה');
 await expect(page.getByLabel('אמונת יסוד 1',{exact:true})).toHaveValue('עריכה שטרם נשמרה');
 expect(f.requests.some(r=>r.body?.action==='save'||r.body?.action==='publish')).toBe(false);
 if(index===0)await page.screenshot({path:info.outputPath('concept-ai-private.png'),fullPage:true});
});
test('concept AI empty and actionable errors',async({context,page})=>{
 await conceptFixture(context);let status=200;
 await context.route('**/functions/v1/suggest-conceptualization-section',r=>r.fulfill({status,json:status===200?{suggestions:[]}:{error:status===413?'input_too_large':'temporary_failure'}}));
 await page.goto(`/app/patients/${patient}/conceptualization`);await page.getByRole('button',{name:'עריכה',exact:true}).click();const section=page.locator('.concept-section').first();
 await section.getByRole('button',{name:'הצעות AI',exact:true}).click();await expect(section.getByText('אין מספיק מידע להצעות')).toBeVisible();
 for(const [code,text] of [[403,'אין הרשאה'],[413,'המידע ארוך'],[429,'בקשות רבות'],[503,'לא הצלחנו']] as const){status=code;await section.getByRole('button',{name:/הצעות AI/}).click();await expect(section.getByRole('alert')).toContainText(text);}
});
test('concept AI late reply cannot enter shared mode',async({context,page})=>{
 await conceptFixture(context);let release!:()=>void;const wait=new Promise<void>(r=>release=r);let calls=0;
 await context.route('**/functions/v1/suggest-conceptualization-section',async r=>{calls++;await wait;await r.fulfill({json:{suggestions:['PRIVATE_AI_SENTINEL']}});});
 await page.goto(`/app/patients/${patient}/conceptualization`);await page.getByRole('button',{name:'עריכה',exact:true}).click();
 await page.locator('.concept-section').first().getByRole('button',{name:'הצעות AI',exact:true}).click();await expect.poll(()=>calls).toBe(1);
 await expect(page.getByRole('button',{name:'מכינים הצעות…'})).toBeDisabled();
 await page.getByRole('link',{name:'התחלת פגישה כעת',exact:true}).click();await expect(page).toHaveURL(/\/shared\//);
 await page.getByRole('link',{name:'המשגה',exact:true}).click();release();
 await expect(page.locator('.concept-reading')).toHaveCount(1);await expect(page.getByRole('button',{name:/הצעות AI/})).toHaveCount(0);await expect(page.getByText('PRIVATE_AI_SENTINEL')).toHaveCount(0);expect(calls).toBe(1);
});

for(const type of ['diary_one','diary_two','diary_three'])test(`reading first ${type} history edit cancel save`,async({context,page},info)=>{
 const f=await fixture(context);await page.goto(`/app/patients/${patient}/${type}?entry=entry`);
 await expect(page.locator('.diary-reading')).toBeVisible();await expect(page.locator('.pw-editor textarea')).toHaveCount(0);
 await expect(page.locator('.diary-reading')).toContainText('מחשבה סינתטית');
 expect(f.requests.filter(r=>r.method==='PATCH'||r.method==='POST'&&r.path.includes('save-'))).toHaveLength(0);
 await page.screenshot({path:info.outputPath(`${type}-reading.png`),fullPage:true});
 await page.getByRole('button',{name:'עריכה',exact:true}).click();const field=page.locator('[data-part="event"] textarea').first();await field.fill('שינוי לביטול');
 page.once('dialog',d=>d.accept());await page.getByRole('button',{name:'ביטול עריכה',exact:true}).click();await expect(page.locator('.diary-reading')).not.toContainText('שינוי לביטול');
 await page.getByRole('button',{name:'עריכה',exact:true}).click();await field.fill('שינוי שנשמר');await page.getByRole('button',{name:'שמירה בתיק המטופל/ת',exact:true}).click();
 await expect(page.locator('.diary-reading')).toContainText('שינוי שנשמר');expect(f.requests.filter(r=>r.method==='PATCH')).toHaveLength(1);expect(f.records[`${type}_entries`]).toHaveLength(1);
 await page.getByRole('button',{name:'רשומה חדשה',exact:true}).click();await expect(page.locator('[data-part="event"] textarea')).toBeVisible();
});
test('reading shared long content focus full and narrow',async({context,page},info)=>{
 const f=await fixture(context);const long='טקסט עברי ארוך עם מספרים 123 וסימני פיסוק (בדיקה). '.repeat(30);f.records.diary_three_entries[0].situation=long;
 await page.setViewportSize({width:1366,height:768});await page.goto(`/app/shared/${patient}/diary_three?entry=entry`);
 await expect(page.locator('.diary-reading')).toBeVisible();await expect(page.locator('textarea')).toHaveCount(0);await expect(page.locator('.diary-reading')).toContainText(long.trim());
 await page.screenshot({path:info.outputPath('shared-focused-reading.png'),fullPage:true});
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();await expect(page.locator('.reading-section').last()).toBeVisible();await expect(page.locator('body')).not.toContainText('PRIVATE_NOTE_SENTINEL');
 await page.screenshot({path:info.outputPath('shared-full-reading.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 await page.screenshot({path:info.outputPath('shared-narrow-reading.png'),fullPage:true});
});

for(const type of ['diary_one','diary_two','diary_three'])test(`reading ${type} read-only permission`,async({context,page})=>{
 const f=await fixture(context,{readOnly:true});await page.goto(`/app/patients/${patient}/${type}?entry=entry`);
 await expect(page.locator('.diary-reading')).toBeVisible();await expect(page.getByRole('button',{name:'עריכה',exact:true})).toHaveCount(0);await expect(page.locator('.pw-editor textarea')).toHaveCount(0);
 expect(f.requests.filter(r=>r.method==='PATCH')).toHaveLength(0);
});

test('core belief worksheet partial saves, published snapshot, conflict, focused/full and privacy',async({context,page},info)=>{
 const f=await fixture(context);let current:Record<string,unknown>={patient_id:patient,document:null,revision:null,updated_at:null,published_revision:null,published_at:null};let sent:unknown=null,serial=0;const calls:Record<string,unknown>[]=[];
 await context.route('**/functions/v1/core-belief-restructuring',async route=>{const body=route.request().postDataJSON();calls.push(body);if(body.action==='load_draft')return route.fulfill({json:current});if(body.expected_revision!==current.revision)return route.fulfill({status:409,json:{error:'revision_conflict'}});if(body.action==='save')current={...current,document:structuredClone(body.document),revision:`revision-${++serial}`,updated_at:'2026-11-22T12:00:00Z'};if(body.action==='publish'){sent=structuredClone(current.document);current={...current,published_revision:current.revision,published_at:'2026-11-22T12:00:00Z'};}return route.fulfill({json:current});});
 await page.setViewportSize({width:1440,height:1000});await page.goto(`/app/shared/${patient}/core_belief`);
 await expect(page.getByRole('heading',{name:'ערעור אמונת יסוד',exact:true})).toBeVisible();
 await expect(page.getByLabel('עכשיו — מחוון',{exact:true}).first()).toHaveValue('80');
 await page.getByLabel('האמונה',{exact:true}).first().fill('A — לפעמים אני חושב שעליי להצליח בכל דבר');await page.getByLabel('עכשיו — אחוז',{exact:true}).first().fill('0');
 await page.getByLabel('עכשיו — מחוון',{exact:true}).first().fill('25');
 await expect(page.getByLabel('עכשיו — אחוז',{exact:true}).first()).toHaveValue('25');
 await page.getByLabel('עכשיו — אחוז',{exact:true}).first().fill('');
 await expect(page.getByLabel('עכשיו — אחוז',{exact:true}).first()).toHaveValue('');
 await page.getByLabel('עכשיו — מחוון',{exact:true}).first().fill('0');
 await page.getByRole('button',{name:'הוספת רגש',exact:true}).first().click();
 await page.getByRole('button',{name:'מודאג',exact:true}).click();
 await page.getByRole('button',{name:'הוספת רגש',exact:true}).first().click();
 await expect(page.locator('[popover]:popover-open').getByRole('button',{name:'מודאג',exact:true})).toHaveCount(0);
 await page.getByRole('button',{name:'עצוב',exact:true}).click();
 await page.getByRole('button',{name:'הסרת רגש: עצוב',exact:true}).click();
 await page.screenshot({animations:'disabled',path:info.outputPath('core-focused.png')});
 await page.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();await expect(page.getByLabel('האמונה',{exact:true}).first()).toHaveValue('A — לפעמים אני חושב שעליי להצליח בכל דבר');
 await page.getByLabel('התנהגות חדשה / ניסויים',{exact:true}).fill('לנסות צעד קטן ולבחון מה קורה בפועל.');
 await page.screenshot({animations:'disabled',path:info.outputPath('core-overview-edit.png'),fullPage:true});
 await expect(page.getByRole('button',{name:'שליחת עותק למטופל/ת',exact:true})).toBeDisabled();await page.getByRole('button',{name:'שמירה',exact:true}).click();await expect(page.getByText('המסמך נשמר',{exact:true})).toBeVisible();
 expect((calls.find(c=>c.action==='save')?.document as Record<string,unknown>).old_now).toBe(0);expect((calls.find(c=>c.action==='save')?.document as Record<string,unknown>).old_most).toBeNull();expect((current.document as Record<string,unknown>).old_feelings).toBe('מודאג');expect(Object.keys(current.document as object)).toHaveLength(16);expect(sent).toBeNull();await expect(page.locator('textarea')).toHaveCount(0);
 await page.getByRole('button',{name:'שליחת עותק למטופל/ת',exact:true}).click();await expect(page.getByText('המסמך נשלח למטופל/ת',{exact:true})).toBeVisible();const a=structuredClone(sent);
 const second=await context.newPage();await second.goto(`/app/shared/${patient}/core_belief`);await second.getByRole('button',{name:'עריכה',exact:true}).click();await second.getByLabel('האמונה',{exact:true}).first().fill('B — אפשר ללמוד גם מטעות');await second.getByRole('button',{name:'שמירה',exact:true}).click();await expect(second.getByText('המסמך נשמר',{exact:true})).toBeVisible();expect(sent).toEqual(a);
 await page.getByRole('button',{name:'שליחת עותק למטופל/ת',exact:true}).click();await expect(page.getByRole('alert')).toContainText('השתנה במכשיר אחר');expect(sent).toEqual(a);
 await page.getByRole('button',{name:'עריכה',exact:true}).click();await page.getByLabel('האמונה',{exact:true}).first().fill('שינויים מקומיים');await page.getByRole('button',{name:'שמירה',exact:true}).click();await expect(page.getByLabel('האמונה',{exact:true}).first()).toHaveValue('שינויים מקומיים');
 await second.getByRole('button',{name:'שליחת עותק למטופל/ת',exact:true}).click();await expect(second.getByText('המסמך נשלח למטופל/ת',{exact:true})).toBeVisible();expect(sent).not.toEqual(a);expect(sent).toEqual(current.document);
 const mutationCount=calls.filter(c=>c.action!=='load_draft').length;
 await second.getByRole('button',{name:'עריכה',exact:true}).click();await second.getByLabel('האמונה',{exact:true}).first().fill('שינוי לביטול');second.once('dialog',dialog=>dialog.accept());await second.getByRole('button',{name:'ביטול עריכה',exact:true}).click();await expect(second.getByText('B — אפשר ללמוד גם מטעות',{exact:true})).toBeVisible();expect(calls.filter(c=>c.action!=='load_draft')).toHaveLength(mutationCount);
 await second.getByRole('button',{name:'תצוגה מלאה',exact:true}).click();await second.screenshot({animations:'disabled',path:info.outputPath('core-overview-read.png'),fullPage:true});
 await second.setViewportSize({width:390,height:844});await second.screenshot({animations:'disabled',path:info.outputPath('core-narrow.png'),fullPage:true});expect(await second.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
 expect(f.requests.some(r=>/load-sessions|load-patients|patient-names|suggest-|anonymize/.test(r.path))).toBe(false);await expect(second.locator('.cb-header,.pw-picker')).toHaveCount(0);await expect(second.getByText('PRIVATE_NOTE_SENTINEL')).toHaveCount(0);await second.close();
});


test('conceptualization load failure shows a load error and retries without writing',async({context,page})=>{
 await fixture(context);const actions:string[]=[];let fail=true;
 await context.route('**/functions/v1/patient-conceptualization',async route=>{
  actions.push(route.request().postDataJSON().action);
  if(fail)return route.abort('failed');
  return route.fulfill({json:{patient_id:patient,document:null,revision:null,published_revision:null,published_at:null}});
 });
 await page.goto(`/app/patients/${patient}/conceptualization`);
 await expect(page.getByRole('alert')).toContainText('לא הצלחנו לטעון את ההמשגה. אפשר לנסות שוב.');
 await expect(page.getByRole('alert')).not.toContainText('השינויים נשארו כאן');
 fail=false;await page.getByRole('button',{name:'טעינה מחדש',exact:true}).click();
 await expect(page.getByRole('button',{name:'יצירת המשגה',exact:true})).toBeVisible();
 expect(actions).toEqual(['load_draft','load_draft']);
});

test('new AI notice gates content, preserves manual edits on decline, and shares server acceptance',async({context,page},info)=>{
 await conceptFixture(context);
 let accepted=false, writes=0, aiCalls=0;
 await context.route('**/rest/v1/rpc/*',async route=>{
  const body=route.request().postDataJSON();if(body?.p_consent_type!=='ai_data_sharing')return route.fallback();
  expect(body.p_required_version).toBe('2026-11-22');
  if(route.request().url().endsWith('/record_my_consent')){writes++;expect(Object.keys(body)).toHaveLength(5);accepted=true;}
  return route.fulfill({json:{therapist_id:user.id,consent_type:'ai_data_sharing',required_version:'2026-11-22',accepted_version:accepted?'2026-11-22':null,accepted_at:accepted?'2026-11-22T10:00:00Z':null,revoked_at:null,status:accepted?'accepted':'required',revision:accepted?1:0}});
 });
 await context.route('**/functions/v1/suggest-conceptualization-section',r=>{aiCalls++;return r.fulfill({json:{suggestions:[]}});});
 await page.goto(`/app/patients/${patient}/conceptualization`);await page.getByRole('button',{name:'עריכה',exact:true}).click();
 await page.getByLabel('אמונת יסוד 1',{exact:true}).fill('טיוטה סינתטית');
 await page.getByRole('button',{name:'הצעות AI',exact:true}).first().click();
 const dialog=page.getByRole('dialog');await expect(dialog).toBeVisible();await expect(dialog).toContainText('שימוש בכלי בינה מלאכותית');await expect(dialog).toContainText('פרטים מזהים אינם מוסרים באופן אוטומטי לפני השליחה.');
 expect(aiCalls).toBe(0);await dialog.getByRole('button',{name:'לא עכשיו',exact:true}).click();await expect(dialog).not.toBeVisible();expect(writes).toBe(0);expect(aiCalls).toBe(0);await expect(page.getByLabel('אמונת יסוד 1',{exact:true})).toHaveValue('טיוטה סינתטית');
 await page.getByRole('button',{name:'הצעות AI',exact:true}).first().click();await expect(dialog).toBeVisible();
 await page.screenshot({path:info.outputPath('ai-consent-hebrew.png'),fullPage:true});
 await dialog.getByRole('button',{name:'אישור והמשך',exact:true}).click();await expect(dialog).not.toBeVisible();await expect.poll(()=>aiCalls).toBe(1);
 const second=await context.newPage();await second.goto(`/app/patients/${patient}/conceptualization`);await second.getByRole('button',{name:'עריכה',exact:true}).click();await second.getByRole('button',{name:'הצעות AI',exact:true}).first().click();await expect.poll(()=>aiCalls).toBe(2);await expect(second.getByRole('dialog')).not.toBeVisible();expect(writes).toBe(1);
});
