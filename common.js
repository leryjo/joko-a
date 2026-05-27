const fs = require('fs');
const path = require('path');
const axios = require('axios');
const FormData = require('form-data');
const {Builder, By, Key, until} = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');

const CODE_DIR = process.env.CODE_DIR || __dirname;
const BASE_DIR = process.env.BASE_DIR || path.join(CODE_DIR, 'joko-idx');
const CHROME_BINARY = (process.env.CHROME_BINARY || '/usr/bin/chromium').trim();
const CHROMEDRIVER_PATH = (process.env.CHROMEDRIVER_PATH || '/usr/bin/chromedriver').trim();
const TG_TOKEN = (process.env.TG_TOKEN || '8333206393:AAG8Z76SSbgAEAC1a3oPT8XhAF9t_rDOq3A').trim();
const TG_CHAT_ID = (process.env.TG_CHAT_ID || '-1003532458425').trim();

function ensureDir(p){ fs.mkdirSync(p, {recursive:true}); }
function sleep(ms){ return new Promise(r=>setTimeout(r, ms)); }
function nowTag(){ const d=new Date(); const pad=n=>String(n).padStart(2,'0'); return `${d.getFullYear()}${pad(d.getMonth()+1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`; }
function nowStr(){ const d=new Date(); const pad=n=>String(n).padStart(2,'0'); return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`; }
function readLines(file){ if(!fs.existsSync(file)) return []; return fs.readFileSync(file,'utf8').split(/\r?\n/).map(s=>s.trim()).filter(Boolean); }
function touch(file){ ensureDir(path.dirname(file)); if(!fs.existsSync(file)) fs.writeFileSync(file,''); }
function append(file, text){ ensureDir(path.dirname(file)); fs.appendFileSync(file, text); }
function maskEmail(email){ try{ const [n,d]=email.split('@'); return `${n.slice(0,2)}***@${d}`; }catch(e){ return email; } }
function tgEnabled(){ return !!(TG_TOKEN && TG_CHAT_ID); }
async function tgSendText(text){ if(!tgEnabled()) return false; try{ const url=`https://api.telegram.org/bot${TG_TOKEN}/sendMessage`; const body=new URLSearchParams({chat_id:TG_CHAT_ID,text,parse_mode:'HTML'}); const r=await axios.post(url, body, {timeout:30000}); return r.status>=200&&r.status<300; }catch(e){ return false; } }
async function tgSendPhoto(caption, photoPath){ if(!tgEnabled()) return false; if(!photoPath || !fs.existsSync(photoPath)) return tgSendText(caption); try{ const url=`https://api.telegram.org/bot${TG_TOKEN}/sendPhoto`; const form=new FormData(); form.append('chat_id', TG_CHAT_ID); form.append('caption', caption); form.append('parse_mode', 'HTML'); form.append('photo', fs.createReadStream(photoPath)); const r=await axios.post(url, form, {headers:form.getHeaders(), timeout:60000}); return r.status>=200&&r.status<300; }catch(e){ return tgSendText(caption); } }
function chromeOptions(userDataDir, profileDir='Default', extra=[]){ ensureDir(userDataDir); const opts=new chrome.Options(); if(CHROME_BINARY) opts.setChromeBinaryPath(CHROME_BINARY); opts.addArguments(`--user-data-dir=${userDataDir}`, `--profile-directory=${profileDir}`, '--no-sandbox','--disable-dev-shm-usage','--disable-gpu','--disable-notifications','--disable-popup-blocking','--disable-extensions','--disable-sync','--disable-features=SyncPromo,SigninPromo','--disable-blink-features=AutomationControlled','--no-first-run','--no-default-browser-check','--remote-allow-origins=*','--test-type','--simulate-outdated-no-au=Tue, 31 Dec 2099 23:59:59 GMT','--disable-component-update',...extra); opts.excludeSwitches('enable-automation','enable-logging'); opts.setUserPreferences({'credentials_enable_service':false,'profile.password_manager_enabled':false,'profile.default_content_setting_values.notifications':2,'sync_promo.show_on_first_run':false,'signin.allowed':false,'profile.exit_type':'Normal','profile.exited_cleanly':true}); if(process.env.HEADLESS === '1') opts.addArguments('--headless=new'); return opts; }
async function buildDriver(userDataDir, profileDir='Default', extra=[]){ const service=new chrome.ServiceBuilder(CHROMEDRIVER_PATH); const driver=await new Builder().forBrowser('chrome').setChromeOptions(chromeOptions(userDataDir, profileDir, extra)).setChromeService(service).build(); await driver.manage().setTimeouts({pageLoad:120000, implicit:0, script:30000}); try{ await driver.executeScript("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"); }catch(e){} return driver; }
async function screenshot(driver, file){ try{ ensureDir(path.dirname(file)); const png=await driver.takeScreenshot(); fs.writeFileSync(file, png, 'base64'); return file; }catch(e){ return ''; } }
function safeReadJson(file, def={}){ try{ if(!fs.existsSync(file)) return def; return JSON.parse(fs.readFileSync(file,'utf8') || '{}'); }catch(e){ return def; } }
function safeWriteJson(file, data){ ensureDir(path.dirname(file)); fs.writeFileSync(file+'.tmp', JSON.stringify(data,null,0)); fs.renameSync(file+'.tmp', file); }
module.exports={fs,path,axios,Builder,By,Key,until,chrome,CODE_DIR,BASE_DIR,TG_TOKEN,TG_CHAT_ID,ensureDir,sleep,nowTag,nowStr,readLines,touch,append,maskEmail,tgSendText,tgSendPhoto,buildDriver,screenshot,safeReadJson,safeWriteJson};
