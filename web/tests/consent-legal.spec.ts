import {test,expect} from '@playwright/test';
import {readFileSync} from 'node:fs';
const legal=JSON.parse(readFileSync(new URL('../src/legal-he.json',import.meta.url),'utf8'));
for(const width of [1440,390]) for(const doc of ['terms','privacy'] as const) {
 test(`${doc} legal parity at ${width}`,async({page},testInfo)=>{
  await page.setViewportSize({width,height:900});
  const body=legal[doc==='terms'?'termsBody':'privacyBody'];
  await page.goto(`/${doc}/`);
  await expect(page.locator('.canonical-legal')).toHaveText(body,{useInnerText:false});
  expect(await page.locator('.canonical-legal').textContent()).toBe(body);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
  await page.screenshot({path:testInfo.outputPath(`${doc}-${width}.png`)});
  await page.goto(`/app/legal/${doc}`);
  expect(await page.locator('.prose').textContent()).toBe(body);
  await page.screenshot({path:testInfo.outputPath(`app-${doc}-${width}.png`)});
 });
}
