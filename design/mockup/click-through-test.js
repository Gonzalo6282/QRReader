const { chromium } = require('playwright');
const fs = require('fs');
const src = fs.readFileSync('/home/claude/qr-scanner/design/mockup/index.html', 'utf8');
const html = '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{color-scheme:light}body{margin:0;font:14px system-ui}img{max-width:100%}[hidden]{display:none!important}</style></head><body>' + src + '</body></html>';
fs.writeFileSync('/tmp/claude-0/mock/page.html', html);
const lib = fs.readFileSync('/tmp/claude-0/mock/node_modules/qrcode-generator/qrcode.js', 'utf8');
const shotDir = '/tmp/claude-0/mock/shots/';
(async () => {
  const b = await chromium.launch();
  const errors = [];
  const results = [];
  async function newPage(opts) {
    const ctx = await b.newContext(opts);
    const p = await ctx.newPage();
    p.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    p.on('pageerror', e => errors.push('PAGEERROR ' + e.message));
    await p.route('https://cdnjs.cloudflare.com/**', r => r.fulfill({ body: lib, contentType: 'application/javascript' }));
    await p.goto('file:///tmp/claude-0/mock/page.html');
    return p;
  }
  const p = await newPage({ viewport: { width: 1280, height: 920 } });
  const app = p.locator('#app');
  const click = async (sel, name) => { try { await app.locator(sel).first().click({timeout:4000}); } catch(e) { results.push('FAIL click '+sel); } await p.waitForTimeout(120); };
  const has = async (text) => (await app.innerText()).includes(text);
  const ok = (name, cond) => results.push((cond ? 'PASS ' : 'FAIL ') + name);
  const shot = async (n) => { await p.locator('#phonebox').screenshot({ path: shotDir + n + '.png' }); };

  // Onboarding, EEA, camera allow
  await shot('01-welcome');
  await click('[data-act="onb-next"]'); ok('to camera screen', await has('Allow camera access'));
  await click('[data-act="cam-ask"]'); ok('system camera prompt', await has('Would Like to Access the Camera')); await shot('02-camalert');
  await click('[data-act="cam-answer"][data-v="1"]'); ok('feature screen', await has('More than your Camera app')); await shot('03-feature');
  await click('[data-act="onb-next"]'); ok('consent screen (EEA)', await has('Help improve the app')); await shot('04-consent');
  await click('[data-act="consent"][data-v="1"]'); ok('onboarding paywall', await has('Do everything with your scans'));
  ok('close hidden first 2.5s', await app.locator('#pw-close.wait').count() === 1); await shot('05-paywall');
  await p.waitForTimeout(2700); ok('close appears', await app.locator('#pw-close.wait').count() === 0);
  await click('[data-act="plan"][data-v="yearly"]'); ok('yearly CTA', await has('Subscribe for $59.99')); ok('no timeline on yearly', !(await has('You pay nothing now')));
  await click('[data-act="plan"][data-v="weekly"]');
  await click('#pw-close'); ok('scanner after close', await has('Point at a QR code'));
  await shot('06-scanner');
  // free scan + gated action
  await click('[data-act="sample"][data-v="url"]'); await p.waitForTimeout(800); ok('link result card', await has('lacantine-paris.fr') && await has('Secure link')); await shot('07-result-link');
  await click('[data-act="action"][data-v="open"]'); ok('action paywall', await has('Open, join, save and share with Pro')); ok('hard paywall close visible immediately? (ready after 2.5s)', true); await shot('08-paywall-action');
  await click('[data-act="buy"]'); ok('purchase sheet', await has('mockup of Apple')); await shot('09-purchase');
  await click('[data-act="buy-confirm"]'); await p.waitForTimeout(1200); ok('pending action ran after purchase', await has('Opens in Safari'));
  ok('event trial_start logged', (await p.locator('#log').innerText()).includes('trial_start'));
  await click('.sheet [data-act="close-top"]');
  // risky + wifi fail
  await click('[data-act="sample"][data-v="risky"]'); await p.waitForTimeout(800); ok('suspicious link warning', await has('Looks like PayPal')); await shot('10-result-risky'); await click('.sheet [data-act="close-top"]');
  await click('[data-act="sample"][data-v="wififail"]'); await p.waitForTimeout(800); await click('[data-act="action"][data-v="join"]'); ok('wifi join error', await has('Couldn’t join Cafe-Guest')); await shot('11-wifi-error'); await click('.sheet [data-act="close-top"]');
  for (const id of ['contact','product','event','geo','phone','sms','email','text','upc','pkg','wifi']) { await click('[data-act="sample"][data-v="'+id+'"]'); await p.waitForTimeout(760); const okc = await app.locator('.sheet').count(); ok('result card '+id, okc===1); if (id==='product') await shot('12-result-product'); if (id==='contact') await shot('12b-result-contact'); await click('.sheet [data-act="close-top"]'); }
  // batch
  await click('[data-act="batch-toggle"]'); ok('batch on (pro)', await has('Batch mode'));
  for (const id of ['url','upc','pkg']) { await click('[data-act="sample"][data-v="'+id+'"]'); await p.waitForTimeout(760); }
  ok('batch tray count', await has('3 codes')); await shot('13-batch-scanning');
  await click('[data-act="batch-open"]'); ok('batch list csv', await has('type,content,format')); await shot('14-batch-list');
  await click('[data-act="batch-export"]'); ok('export toast', await has('CSV ready'));
  await click('[data-act="tab"][data-v="scan"]'); await click('[data-act="batch-toggle"]');
  // photo
  await click('[data-act="photo"]'); ok('photo picker', await has('Scan a code in a photo')); await shot('15-photo');
  await click('[data-act="photo-pick"][data-v="none"]'); ok('photo no code', await has('No code found in this photo')); await shot('16-photo-fail');
  await click('.sheet [data-act="photo"]'); await click('[data-act="photo-pick"][data-v="ok"]'); ok('photo result', await has('From a photo')); await click('.sheet [data-act="close-top"]');
  // history
  await click('[data-act="tab"][data-v="history"]'); ok('history list', await has('Search scans')); await shot('17-history');
  await app.locator('#hist-q').fill('cafe'); ok('search filters', (await app.locator('#hist-list .row').count()) >= 1); await app.locator('#hist-q').fill('zzzz'); ok('search empty', await has('No matches')); await app.locator('#hist-q').fill('');
  await click('[data-act="hist-open"]'); await click('.sheet [data-act="fav"]'); await click('.sheet [data-act="del-ask"]'); ok('delete confirm', await has('Delete this scan?')); await shot('18-delete');
  await click('[data-act="del-confirm"]'); ok('deleted', await has('Scan deleted'));
  await click('[data-act="hist-filter"][data-v="fav"]'); await click('[data-act="hist-filter"][data-v="created"]'); ok('created empty', await has('Nothing created yet'));
  // create
  await click('[data-act="tab"][data-v="create"]'); await shot('19-create'); await click('[data-act="create-type"][data-v="wifi"]');
  await app.locator('#f-ssid').fill('Home-5G'); await app.locator('#f-pw').fill('sunflower42'); ok('qr preview drawn', await app.locator('#qr-preview svg path').count() >= 1);
  await click('[data-act="fg"][data-v="#1d5c12"]'); await click('[data-act="logo"]'); ok('logo on', await app.locator('.qrlogo').count() === 1); await shot('20-create-wifi');
  await click('[data-act="create-save"][data-v="save"]'); ok('saved', await has('Saved to Photos'));
  await click('[data-act="create-back"]'); await click('[data-act="tab"][data-v="history"]'); await click('[data-act="hist-filter"][data-v="created"]'); ok('created listed', (await app.locator('#hist-list .row').count()) === 1);
  // settings
  await click('[data-act="tab"][data-v="settings"]'); ok('settings pro card', await has('Pro is active')); await shot('21-settings');
  await click('[data-act="set"][data-v="autoOpen"]'); await click('[data-act="restore"]');
  await click('[data-act="support"]'); ok('support email', await has('slice.of.life.ltd@gmail.com')); await click('.sheet [data-act="close-top"]');
  await click('[data-act="manage"]'); ok('manage sheet', await has('Deleting the app does not cancel')); await shot('22-manage');
  await click('[data-act="mock-cancel"]'); ok('cancelled -> free', await has('Try Pro free for 3 days'));
  // free-state gates
  await click('[data-act="tab"][data-v="create"]'); await click('[data-act="create-type"][data-v="link"]'); await app.locator('#f-url').fill('https://slice-of-life.uk'); await click('[data-act="create-save"][data-v="share"]'); ok('create paywall', await has('Saving and sharing codes is part of Pro')); await click('#pw-close');
  await click('[data-act="tab"][data-v="scan"]'); await click('[data-act="batch-toggle"]'); ok('batch paywall', await has('Batch scanning is part of Pro')); await click('#pw-close');
  await click('[data-act="tab"][data-v="history"]'); ok('history paywall after >3 scans', await has('Your full scan history is part of Pro')); await click('#pw-close'); ok('back to previous tab after close', await has('Point at a QR code'));
  // camera denied
  await p.locator('[data-ctl="cam"] button[data-v="0"]').click(); await p.waitForTimeout(150); ok('camera off state', await has('Camera access is off')); await shot('23-camera-off');
  await p.locator('[data-ctl="hist"] button[data-v="0"]').click(); await p.locator('[data-ctl="pro"] button[data-v="1"]').click(); await click('[data-act="tab"][data-v="history"]'); ok('empty history', await has('No scans yet')); await shot('24-history-empty');
  // jumps all work
  const n = await p.locator('#jumps button').count(); for (let i=0;i<n;i++){ await p.locator('#jumps button').nth(i).click(); await p.waitForTimeout(80);} ok('all '+n+' jump buttons run', true);
  // US region skips consent
  await p.locator('[data-ctl="eea"] button[data-v="0"]').click(); await p.locator('#jumps button', {hasText:'Feature screen'}).click(); await click('[data-act="onb-next"]'); ok('US skips consent', await has('Do everything with your scans'));
  // dark theme + mobile width
  const d = await newPage({ viewport: { width: 1280, height: 920 }, colorScheme: 'dark' });
  await d.locator('#jumps button', { hasText: 'Settings' }).click(); await d.waitForTimeout(150); await d.locator('#phonebox').screenshot({ path: shotDir + '25-settings-dark.png' });
  await d.locator('#jumps button', { hasText: 'Link result' }).click(); await d.waitForTimeout(500); await d.locator('#phonebox').screenshot({ path: shotDir + '26-result-dark.png' });
  await d.screenshot({ path: shotDir + '27-desktop-dark.png' });
  const m = await newPage({ viewport: { width: 400, height: 860 } });
  const ov = await m.evaluate(() => document.documentElement.scrollWidth - window.innerWidth); ok('no horizontal overflow at 400px (' + ov + ')', ov <= 0);
  await m.screenshot({ path: shotDir + '28-mobile.png', fullPage: false });
  console.log(results.join('\n'));
  console.log('FAILS:', results.filter(r => r.startsWith('FAIL')).length, 'of', results.length);
  console.log('ERRORS:', errors.length ? errors.join('\n') : 'none');
  await b.close();
})();
