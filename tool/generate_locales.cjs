const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
const app=JSON.parse(fs.readFileSync(path.join(root,'locales/app.json'),'utf8')),pages=JSON.parse(fs.readFileSync(path.join(root,'locales/pages.json'),'utf8'));
const placeholders=s=>[...s.matchAll(/\{\d+\}/g)].map(m=>m[0]).sort().join(',');
for(const [key,values] of Object.entries({...app,...pages})){if(values.length!==2||values.some(v=>!v||placeholders(v)!==placeholders(key)))throw Error('Invalid translation: '+key);}
const dart=s=>JSON.stringify(s).replaceAll('$','\\$');
fs.writeFileSync(path.join(root,'lib/i18n_catalog.dart'),'// Generated from locales/app.json using node tool/generate_locales.cjs.\nconst passyTranslations=<String,List<String>>{\n'+Object.entries(app).map(([k,v])=>`${dart(k)}:[${v.map(dart).join(',')}],`).join('\n')+'\n};\n');
fs.writeFileSync(path.join(root,'web/story-assets/translations.js'),'window.PassyTranslations='+JSON.stringify({...app,...pages})+';\n');
console.log(`Validated and generated ${Object.keys(app).length} app and ${Object.keys(pages).length} page translations.`);
