const {fs,path,By,Key,until,BASE_DIR,ensureDir,sleep,nowTag,readLines,touch,maskEmail,tgSendText,tgSendPhoto,buildDriver,screenshot} = require('./common');

const EMAIL_FILE = path.join(BASE_DIR, 'email.txt');
const MAPPING_FILE = path.join(BASE_DIR, 'mapping_profil.txt');
const PROFILES_ROOT = path.resolve(process.env.PROFILES_ROOT || path.join(BASE_DIR, 'chrome_profiles'));
const SNAP_DIR = process.env.SNAP_DIR || path.join(BASE_DIR, 'snapshots');
const LOGIN_MAX_MIN = (process.env.LOGIN_MAX_MIN || '').trim();
const LOGIN_MAX_SEC = /^\d+$/.test(LOGIN_MAX_MIN) ? parseInt(LOGIN_MAX_MIN,10)*60 : null;
const POLL_SEC = parseFloat(process.env.POLL_SEC || '2');

const MAX_PARALLEL = 1;

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

async function runOne(idx, email, pwd){

  const profileName=`joko${idx}`;
  const userDataDir=path.join(PROFILES_ROOT, profileName);

  let driver=null;

  console.log('='.repeat(70));
  console.log(`[▶] LOGIN SATU AKUN #${idx} | ${email}`);
  console.log(`[i] profile folder: ${userDataDir}`);

  try{

    driver=await buildDriver(
      userDataDir,
      'Default',
      ['--window-size=800,800']
    );

    await driver.get('https://accounts.google.com/signin/v2/identifier');

    await sleep(5000);

    const emailBox=await driver.wait(
      until.elementLocated(By.id('identifierId')),
      60000
    );

    await emailBox.sendKeys(email);

    try{
      await driver.findElement(By.id('identifierNext')).click();
    }catch(e){
      await emailBox.sendKeys(Key.ENTER);
    }

    await sleep(5000);

    const pwdBox=await driver.wait(
      until.elementLocated(By.name('Passwd')),
      60000
    );

    await pwdBox.sendKeys(pwd);

    try{
      await driver.findElement(By.id('passwordNext')).click();
    }catch(e){
      await pwdBox.sendKeys(Key.ENTER);
    }

    await sleep(15000);

    console.log(`[DONE] LOGIN SELESAI #${idx}`);

    return true;

  }catch(e){

    console.log(`[ERROR] ${email}`);
    console.log(e);

    return false;

  }finally{

    try{
      if(driver){
        await driver.quit();
      }
    }catch(e){}

  }
}

async function main(){

  const accounts=readAccounts();

  if(!accounts.length){
    console.log('[ERROR] email.txt kosong');
    return;
  }

  writeMapping(accounts.length);

  await tgSendText(
    `🚀 LOGIN START\nMODE: SINGLE LOGIN (1 akun)`
  );

  let ok=0;

  for(let i=0;i<accounts.length;i++){

    const acc = accounts[i];

    console.log(`\n[WAIT] LOGIN SATU PER SATU -> ${acc.email}`);

    const res = await runOne(
      i + 1,
      acc.email,
      acc.pwd
    );

    if(res) ok++;

    await sleep(5000);

  }

  await tgSendText(
    `✅ LOGIN FINISH\nOK: ${ok}/${accounts.length}`
  );

  console.log('[DONE] semua akun selesai.');
}

main().catch(e=>{
  console.error(e);
  process.exit(1);
});
