const {fs,path,By,Key,until,BASE_DIR,ensureDir,sleep,nowTag,readLines,touch,maskEmail,tgSendText,tgSendPhoto,buildDriver,screenshot} = require('./common');

const EMAIL_FILE = path.join(BASE_DIR, 'email.txt');
const MAPPING_FILE = path.join(BASE_DIR, 'mapping_profil.txt');
const PROFILES_ROOT = path.resolve(process.env.PROFILES_ROOT || path.join(BASE_DIR, 'chrome_profiles'));
const SNAP_DIR = process.env.SNAP_DIR || path.join(BASE_DIR, 'snapshots');
const LOGIN_MAX_MIN = (process.env.LOGIN_MAX_MIN || '').trim();
const LOGIN_MAX_SEC = /^\d+$/.test(LOGIN_MAX_MIN) ? parseInt(LOGIN_MAX_MIN,10)*60 : null;
const POLL_SEC = parseFloat(process.env.POLL_SEC || '2');
const MAX_PARALLEL = 1;
ensureDir(PROFILES_ROOT); ensureDir(SNAP_DIR); touch(EMAIL_FILE);

function snapPath(idx, kind){ return path.join(SNAP_DIR, `acc${idx}_${kind}_${nowTag()}.png`); }
function readAccounts(){ return readLines(EMAIL_FILE).filter(l=>l.includes('|')).map(l=>{ const [e,...p]=l.split('|'); return {email:e.trim(), pwd:p.join('|').trim()}; }).filter(a=>a.email&&a.pwd); }
function writeMapping(count){ let out=''; for(let i=1;i<=count;i++){ const name=`joko${i}`; out += `${path.join(PROFILES_ROOT,name)}|${name}\n`; } fs.writeFileSync(MAPPING_FILE, out); }
async function isLoginSuccess(driver){ try{ const url=(await driver.getCurrentUrl()).toLowerCase(); if(url.includes('myaccount.google.com')||url.includes('mail.google.com')) return true; if(url.includes('accounts.google.com') && !url.includes('challenge') && !url.includes('/signin') && !url.includes('select')) return true; const sels=["img[alt*='Google Account']","a[aria-label*='Google Account']","button[aria-label*='Google Account']","[aria-label*='Akun Google']","[aria-label*='Google Account']"]; for(const s of sels){ if((await driver.findElements(By.css(s))).length) return true; } }catch(e){} return false; }
async function isOtpChallenge(driver){ try{ const url=(await driver.getCurrentUrl()).toLowerCase(); if(url.includes('accounts.google.com') && url.includes('challenge')) return true; for(const s of ["input[type='tel']","input[type='number']","input[name='totpPin']","input[id*='totp']"]){ if((await driver.findElements(By.css(s))).length) return true; } const page=(await driver.getPageSource()).toLowerCase(); return ['verify it\'s you','verify it’s you','2-step verification','enter the code','verification code','kode verifikasi','verifikasi','otp'].some(k=>page.includes(k)); }catch(e){ return false; } }
async function waitUntilDone(driver, idx, email){ let otpNotified=false, successNotified=false; const start=Date.now(); while(true){ try{ const handles=await driver.getAllWindowHandles(); if(!handles.length) return false; }catch(e){ return false; }
    if(await isLoginSuccess(driver)){ if(!successNotified){ const sp=snapPath(idx,'SUCCESS'); await screenshot(driver, sp); await tgSendPhoto(`✅ <b>LOGIN SUKSES</b>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`, sp); successNotified=true; }
      try{ await driver.get('https://studio.firebase.google.com/'); await sleep(15000); const sp=snapPath(idx,'FIREBASE_STUDIO'); await screenshot(driver, sp); await tgSendPhoto(`🚀 <b>MASUK FIREBASE STUDIO</b>\nAkun: <code>${maskEmail(email)}</code>\nStatus: OTP selesai → redirect otomatis\nTime: <code>${nowTag()}</code>`, sp); }catch(e){ await tgSendText(`⚠️ Gagal masuk Firebase Studio\nAkun: ${maskEmail(email)}\nErr: ${String(e).slice(0,150)}`); }
      return true; }
    if((await isOtpChallenge(driver)) && !otpNotified){ const sp=snapPath(idx,'OTP'); await screenshot(driver, sp); await tgSendPhoto(`🔐 <b>OTP / VERIFIKASI TERDETEKSI</b>\nAkun: <code>${maskEmail(email)}</code>\nAction: Selesaikan OTP di Chrome\nTime: <code>${nowTag()}</code>`, sp); otpNotified=true; }
    if(LOGIN_MAX_SEC && (Date.now()-start)/1000 > LOGIN_MAX_SEC){ const sp=snapPath(idx,'TIMEOUT'); await screenshot(driver, sp); await tgSendPhoto(`⏰ <b>TIMEOUT MENUNGGU LOGIN</b>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`, sp); return false; }
    await sleep(POLL_SEC*1000);
  } }
async function googleLoginFlow(driver, idx, email, pwd){ const waitMs=60000; await driver.get('https://accounts.google.com/signin/v2/identifier'); await sleep(5000);
  try{ const emailBox=await driver.wait(until.elementLocated(By.id('identifierId')), waitMs); await driver.wait(until.elementIsVisible(emailBox), waitMs); await emailBox.click(); await emailBox.clear(); await emailBox.sendKeys(email); try{ await driver.findElement(By.id('identifierNext')).click(); }catch(e){ await emailBox.sendKeys(Key.ENTER); } const sp=snapPath(idx,'EMAIL_TYPED'); await screenshot(driver, sp); await tgSendPhoto(`✉️ <b>EMAIL DIKETIK</b>\n#email: <code>${idx}</code>\n#clone: <code>joko${idx}</code>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`, sp); }catch(e){ const sp=snapPath(idx,'EMAIL_FAIL'); await screenshot(driver, sp); await tgSendPhoto(`❌ EMAIL FAIL\nAkun: <code>${maskEmail(email)}</code>\nErr: <code>${String(e).slice(0,200)}</code>`, sp); return false; }
  await sleep(5000); try{ const sp=snapPath(idx,'BEFORE_PASSWORD_WAIT'); await screenshot(driver, sp); await tgSendPhoto(`⏳ <b>BEFORE PASSWORD WAIT</b>\n#email: <code>${idx}</code>\n#clone: <code>joko${idx}</code>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`, sp); }catch(e){}
  try{ const pwdBox=await driver.wait(until.elementLocated(By.name('Passwd')), waitMs); await driver.wait(until.elementIsVisible(pwdBox), waitMs); await pwdBox.click(); await pwdBox.clear(); await pwdBox.sendKeys(pwd); try{ await driver.findElement(By.id('passwordNext')).click(); }catch(e){ await pwdBox.sendKeys(Key.ENTER); } const sp=snapPath(idx,'PASS_TYPED'); await screenshot(driver, sp); await tgSendPhoto(`🔑 <b>PASSWORD DIKETIK</b>\n#email: <code>${idx}</code>\n#clone: <code>joko${idx}</code>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`, sp); await sleep(5000); }catch(e){ const sp=snapPath(idx,'PASS_FAIL'); await screenshot(driver, sp); await tgSendPhoto(`❌ PASS FAIL\nAkun: <code>${maskEmail(email)}</code>\nErr: <code>${String(e).slice(0,200)}</code>`, sp); return false; }
  const sp=snapPath(idx,'AFTER_PASSWORD'); await screenshot(driver, sp); await tgSendPhoto(`📸 <b>SETELAH SUBMIT PASSWORD</b>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>\nNote: Jika muncul OTP, akan dikirim notif terpisah.`, sp); return waitUntilDone(driver, idx, email); }
async function runOne(idx, email, pwd){ const profileName=`joko${idx}`; const userDataDir=path.join(PROFILES_ROOT, profileName); let driver=null; console.log('='.repeat(70)); console.log(`[▶] AKUN #${idx} | ${email}`); console.log(`[i] profile folder: ${userDataDir}`); try{ driver=await buildDriver(userDataDir,'Default',['--window-size=800,800']); const ok=await googleLoginFlow(driver, idx, email, pwd); try{ await driver.quit(); }catch(e){} console.log(ok ? `[✅] DONE #${idx} (${profileName})` : `[⚠️] NOT OK #${idx} (${profileName})`); return ok; }catch(e){ console.error(`[❌] ERROR akun #${idx}:`, e); const sp=driver ? await screenshot(driver, snapPath(idx,'ERROR')) : ''; await tgSendPhoto(`❌ <b>ERROR FATAL</b>\nAkun: <code>${maskEmail(email)}</code>\nProfile: <code>${profileName}</code>\nErr: <code>${String(e).slice(0,240)}</code>\nTime: <code>${nowTag()}</code>`, sp); if(driver) try{ await driver.quit(); }catch(_){} return false; } }
async function main(){
  const accounts=readAccounts();

  if(!accounts.length){
    console.log(`[❌] Tidak ada akun valid di ${EMAIL_FILE}`);
    console.log('Format: email|password');
    return;
  }

  writeMapping(accounts.length);

  await tgSendText(
    `🚀 <b>LOGIN START</b>
` +
    `Total akun: <code>${accounts.length}</code>
` +
    `PROFILES_ROOT: <code>${PROFILES_ROOT}</code>
` +
    `HEADLESS: <code>${process.env.HEADLESS==='1'?1:0}</code>
` +
    `MODE: <code>SEQUENTIAL / SATU PER SATU</code>`
  );

  let ok=0;

  for(let i=0; i<accounts.length; i++){
    const acc = accounts[i];
    const urutan = i + 1;

    console.log('='.repeat(70));
    console.log(`[QUEUE] Mulai login urutan #${urutan}/${accounts.length}: ${acc.email}`);
    console.log(`[MODE] Satu Gmail dulu. Akun berikutnya menunggu sampai akun ini selesai.`);

    await tgSendText(
      `▶️ <b>LOGIN URUTAN ${urutan}/${accounts.length}</b>
` +
      `Akun: <code>${maskEmail(acc.email)}</code>
` +
      `Profile: <code>joko${urutan}</code>`
    );

    const res = await runOne(urutan, acc.email, acc.pwd);
    if(res) ok++;

    console.log(`[QUEUE] Selesai urutan #${urutan}. Lanjut urutan berikutnya setelah delay 5 detik.`);
    await sleep(5000);
  }

  await tgSendText(
    `✅ <b>LOGIN FINISH</b>
` +
    `OK: <code>${ok}</code> / Total: <code>${accounts.length}</code>
` +
    `Mode: <code>SEQUENTIAL / SATU PER SATU</code>
` +
    `Semua akun sudah diproses sesuai urutan email.txt.`
  );

  console.log('[DONE] semua akun selesai diproses satu per satu sesuai urutan email.txt.');
}
main().catch(e=>{ console.error(e); process.exit(1); });
