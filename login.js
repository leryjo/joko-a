const {fs,path,By,Key,until,BASE_DIR,ensureDir,sleep,nowTag,readLines,touch,maskEmail,tgSendText,tgSendPhoto,buildDriver,screenshot} = require('./common');

const EMAIL_FILE = path.join(BASE_DIR, 'email.txt');
const MAPPING_FILE = path.join(BASE_DIR, 'mapping_profil.txt');
const PROFILES_ROOT = path.resolve(process.env.PROFILES_ROOT || path.join(BASE_DIR, 'chrome_profiles'));
const SNAP_DIR = path.join(BASE_DIR, 'snapshots');
const LOGIN_MAX_MIN = (process.env.LOGIN_MAX_MIN || '').trim();
const LOGIN_MAX_SEC = /^\d+$/.test(LOGIN_MAX_MIN) ? parseInt(LOGIN_MAX_MIN,10)*60 : null;
const POLL_SEC = parseFloat(process.env.POLL_SEC || '2');

ensureDir(PROFILES_ROOT);
ensureDir(SNAP_DIR);
touch(EMAIL_FILE);

function snapPath(idx, kind){
  return path.join(SNAP_DIR, `acc${idx}_${kind}_${nowTag()}.png`);
}

function readAccounts(){
  return readLines(EMAIL_FILE)
    .filter(l=>l.includes('|'))
    .map(l=>{
      const [e,...p]=l.split('|');
      return {
        email:e.trim(),
        pwd:p.join('|').trim()
      };
    })
    .filter(a=>a.email&&a.pwd);
}

function writeMapping(count){
  let out='';
  for(let i=1;i<=count;i++){
    const name=`joko${i}`;
    out += `${path.join(PROFILES_ROOT,name)}|${name}\n`;
  }
  fs.writeFileSync(MAPPING_FILE, out);
}

async function getPageText(driver){
  try{
    return (await driver.getPageSource()).toLowerCase();
  }catch(e){
    return '';
  }
}

async function isSignedOutOrChooser(driver){
  try{
    const url=(await driver.getCurrentUrl()).toLowerCase();
    const page=await getPageText(driver);

    if(page.includes('choose an account')) return true;
    if(page.includes('signed out')) return true;
    if(page.includes('use another account')) return true;
    if(url.includes('accounts.google.com') && page.includes('remove an account')) return true;

  }catch(e){}

  return false;
}

async function isOtpChallenge(driver){
  try{
    const url=(await driver.getCurrentUrl()).toLowerCase();

    if(url.includes('accounts.google.com') && url.includes('challenge')){
      return true;
    }

    for(const s of [
      "input[type='tel']",
      "input[type='number']",
      "input[name='totpPin']",
      "input[id*='totp']"
    ]){
      if((await driver.findElements(By.css(s))).length){
        return true;
      }
    }

    const page=await getPageText(driver);

    return [
      "verify it's you",
      "verify it’s you",
      "2-step verification",
      "enter the code",
      "verification code",
      "kode verifikasi",
      "verifikasi",
      "otp"
    ].some(k=>page.includes(k));

  }catch(e){
    return false;
  }
}

async function verifyFirebaseSession(driver, idx, email){
  try{
    await driver.get('https://studio.firebase.google.com/');
    await sleep(25000);

    const url=(await driver.getCurrentUrl()).toLowerCase();
    const page=await getPageText(driver);

    if(await isSignedOutOrChooser(driver)){
      const sp=snapPath(idx,'SIGNED_OUT_FIREBASE');
      await screenshot(driver, sp);
      await tgSendPhoto(
        `❌ <b>SESSION BELUM TERSIMPAN / SIGNED OUT</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nStatus: Firebase masih kembali ke Choose an account / Signed out.`,
        sp
      );
      return false;
    }

    if(url.includes('accounts.google.com')){
      const sp=snapPath(idx,'BACK_TO_GOOGLE_LOGIN');
      await screenshot(driver, sp);
      await tgSendPhoto(
        `❌ <b>SESSION BELUM VALID</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nStatus: Firebase masih redirect ke accounts.google.com.`,
        sp
      );
      return false;
    }

    if(
      url.includes('studio.firebase.google.com') ||
      url.includes('idx.google.com') ||
      page.includes('firebase studio') ||
      page.includes('your workspaces') ||
      page.includes('workspace')
    ){
      const sp=snapPath(idx,'FIREBASE_SESSION_OK');
      await screenshot(driver, sp);
      await tgSendPhoto(
        `✅ <b>SESSION FIREBASE VALID</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nStatus: Firebase Studio kebuka tanpa signed out.`,
        sp
      );
      return true;
    }

    return false;

  }catch(e){
    await tgSendText(
      `⚠️ Gagal cek Firebase session\nAkun: ${maskEmail(email)}\nErr: ${String(e).slice(0,180)}`
    );
    return false;
  }
}

async function isBasicGoogleLoginSuccess(driver){
  try{
    const url=(await driver.getCurrentUrl()).toLowerCase();

    if(await isSignedOutOrChooser(driver)) return false;

    if(url.includes('myaccount.google.com')) return true;
    if(url.includes('mail.google.com')) return true;

    if(
      url.includes('accounts.google.com') &&
      !url.includes('challenge') &&
      !url.includes('/signin') &&
      !url.includes('select') &&
      !url.includes('identifier')
    ){
      return true;
    }

    const sels=[
      "img[alt*='Google Account']",
      "a[aria-label*='Google Account']",
      "button[aria-label*='Google Account']",
      "[aria-label*='Akun Google']",
      "[aria-label*='Google Account']"
    ];

    for(const s of sels){
      if((await driver.findElements(By.css(s))).length){
        return true;
      }
    }

  }catch(e){}

  return false;
}

async function waitUntilDone(driver, idx, email){
  let otpNotified=false;
  let successNotified=false;
  const start=Date.now();

  while(true){
    try{
      const handles=await driver.getAllWindowHandles();
      if(!handles.length) return false;
    }catch(e){
      return false;
    }

    if(await isOtpChallenge(driver)){
      if(!otpNotified){
        const sp=snapPath(idx,'OTP');
        await screenshot(driver, sp);
        await tgSendPhoto(
          `🔐 <b>OTP / VERIFIKASI TERDETEKSI</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nAction: Selesaikan OTP di Chrome\nTime: <code>${nowTag()}</code>`,
          sp
        );
        otpNotified=true;
      }

      await sleep(POLL_SEC*1000);
      continue;
    }

    if(await isBasicGoogleLoginSuccess(driver)){
      if(!successNotified){
        const sp=snapPath(idx,'GOOGLE_LOGIN_OK');
        await screenshot(driver, sp);
        await tgSendPhoto(
          `✅ <b>GOOGLE LOGIN TERDETEKSI</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nLanjut cek Firebase session...`,
          sp
        );
        successNotified=true;
      }

      const firebaseOk=await verifyFirebaseSession(driver, idx, email);

      if(firebaseOk){
        return true;
      }

      return false;
    }

    if(LOGIN_MAX_SEC && (Date.now()-start)/1000 > LOGIN_MAX_SEC){
      const sp=snapPath(idx,'TIMEOUT');
      await screenshot(driver, sp);
      await tgSendPhoto(
        `⏰ <b>TIMEOUT MENUNGGU LOGIN</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nTime: <code>${nowTag()}</code>`,
        sp
      );
      return false;
    }

    await sleep(POLL_SEC*1000);
  }
}

async function googleLoginFlow(driver, idx, email, pwd){
  const waitMs=60000;

  await driver.get('https://accounts.google.com/signin/v2/identifier?continue=https%3A%2F%2Fstudio.firebase.google.com%2F');
  await sleep(5000);

  try{
    const emailBox=await driver.wait(
      until.elementLocated(By.id('identifierId')),
      waitMs
    );

    await driver.wait(until.elementIsVisible(emailBox), waitMs);
    await emailBox.click();
    await emailBox.clear();
    await emailBox.sendKeys(email);

    try{
      await driver.findElement(By.id('identifierNext')).click();
    }catch(e){
      await emailBox.sendKeys(Key.ENTER);
    }

    const sp=snapPath(idx,'EMAIL_TYPED');
    await screenshot(driver, sp);

    await tgSendPhoto(
      `✉️ <b>EMAIL DIKETIK</b>\n#email: <code>${idx}</code>\n#clone: <code>joko${idx}</code>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`,
      sp
    );

  }catch(e){
    const sp=snapPath(idx,'EMAIL_FAIL');
    await screenshot(driver, sp);

    await tgSendPhoto(
      `❌ EMAIL FAIL\nAkun: <code>${maskEmail(email)}</code>\nErr: <code>${String(e).slice(0,200)}</code>`,
      sp
    );

    return false;
  }

  await sleep(5000);

  try{
    const pwdBox=await driver.wait(
      until.elementLocated(By.name('Passwd')),
      waitMs
    );

    await driver.wait(until.elementIsVisible(pwdBox), waitMs);
    await pwdBox.click();
    await pwdBox.clear();
    await pwdBox.sendKeys(pwd);

    try{
      await driver.findElement(By.id('passwordNext')).click();
    }catch(e){
      await pwdBox.sendKeys(Key.ENTER);
    }

    const sp=snapPath(idx,'PASS_TYPED');
    await screenshot(driver, sp);

    await tgSendPhoto(
      `🔑 <b>PASSWORD DIKETIK</b>\n#email: <code>${idx}</code>\n#clone: <code>joko${idx}</code>\nAkun: <code>${maskEmail(email)}</code>\nTime: <code>${nowTag()}</code>`,
      sp
    );

    await sleep(5000);

  }catch(e){
    const sp=snapPath(idx,'PASS_FAIL');
    await screenshot(driver, sp);

    await tgSendPhoto(
      `❌ PASS FAIL\nAkun: <code>${maskEmail(email)}</code>\nErr: <code>${String(e).slice(0,200)}</code>`,
      sp
    );

    return false;
  }

  const sp=snapPath(idx,'AFTER_PASSWORD');
  await screenshot(driver, sp);

  await tgSendPhoto(
    `📸 <b>SETELAH SUBMIT PASSWORD</b>\nAkun: <code>${maskEmail(email)}</code>\nClone: <code>joko${idx}</code>\nTime: <code>${nowTag()}</code>\nNote: Login baru dianggap sukses kalau Firebase Studio tidak Signed out.`,
    sp
  );

  return waitUntilDone(driver, idx, email);
}

async function runOne(idx, email, pwd){
  const profileName=`joko${idx}`;
  const userDataDir=path.join(PROFILES_ROOT, profileName);

  let driver=null;

  console.log('='.repeat(70));
  console.log(`[▶] AKUN #${idx} | ${email}`);
  console.log(`[i] profile folder: ${userDataDir}`);

  try{
    driver=await buildDriver(
      userDataDir,
      'Default',
      ['--window-size=900,800']
    );

    const ok=await googleLoginFlow(driver, idx, email, pwd);

    if(ok){
      console.log(`[SAVE] Session Firebase valid. Menunggu 120 detik supaya profile tersimpan...`);

      try{
        await driver.get('https://studio.firebase.google.com/');
        await sleep(60000);
      }catch(e){}

      try{
        await driver.get('https://accounts.google.com/');
        await sleep(20000);
      }catch(e){}

      try{
        await driver.get('https://studio.firebase.google.com/');
        await sleep(40000);
      }catch(e){}

      console.log(`[SAVE] Session selesai disimpan untuk ${profileName}`);
    }

    try{
      await driver.quit();
    }catch(e){}

    console.log(
      ok
        ? `[✅] DONE #${idx} (${profileName})`
        : `[⚠️] NOT OK #${idx} (${profileName})`
    );

    return ok;

  }catch(e){
    console.error(`[❌] ERROR akun #${idx}:`, e);

    const sp=driver
      ? await screenshot(driver, snapPath(idx,'ERROR'))
      : '';

    await tgSendPhoto(
      `❌ <b>ERROR FATAL</b>\nAkun: <code>${maskEmail(email)}</code>\nProfile: <code>${profileName}</code>\nErr: <code>${String(e).slice(0,240)}</code>\nTime: <code>${nowTag()}</code>`,
      sp
    );

    if(driver){
      try{
        await driver.quit();
      }catch(_){}
    }

    return false;
  }
}

async function main(){
  const accounts = readAccounts();

  if(!accounts.length){
    console.log(`[❌] Tidak ada akun valid di ${EMAIL_FILE}`);
    console.log('Format: email@gmail.com|password');
    return;
  }

  writeMapping(accounts.length);

  await tgSendText(
    `🚀 <b>LOGIN START</b>\nMODE: <code>SEQUENTIAL 1 BY 1 + FIREBASE SESSION CHECK</code>\nTotal email: <code>${accounts.length}</code>`
  );

  let ok = 0;

  for(let i = 0; i < accounts.length; i++){
    const acc = accounts[i];

    console.log('\n===================================================');
    console.log(`[START] LOGIN GMAIL KE-${i + 1}`);
    console.log(`[EMAIL] ${acc.email}`);
    console.log('===================================================\n');

    const result = await runOne(
      i + 1,
      acc.email,
      acc.pwd
    );

    if(result){
      ok++;
      console.log(`\n[DONE] SELESAI GMAIL KE-${i + 1}, LANJUT KE EMAIL BERIKUTNYA\n`);
      await sleep(10000);
    }else{
      console.log(`\n[STOP] GMAIL KE-${i + 1} BELUM VALID / MASIH SIGNED OUT. TIDAK LANJUT KE EMAIL BERIKUTNYA.\n`);

      await tgSendText(
        `🛑 <b>LOGIN STOP</b>\nGmail ke-${i + 1} belum valid untuk Firebase.\nEmail: <code>${maskEmail(acc.email)}</code>\nTidak lanjut ke email berikutnya.`
      );

      break;
    }
  }

  await tgSendText(
    `✅ <b>LOGIN FINISH</b>\nOK: <code>${ok}</code> / Total email: <code>${accounts.length}</code>\nMode: <code>SEQUENTIAL 1 BY 1</code>`
  );

  console.log('[DONE] proses login selesai.');
}

main().catch(e=>{
  console.error(e);
  process.exit(1);
});
