const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = readFileSync(require('node:path').join(__dirname,'../web/story-entry.js'),'utf8');
function route(path, seen=false, storageThrows=false) {
  let redirect = null;
  const location = {href:`https://example.com${path}`,replace(url){redirect=String(url)}};
  const localStorage = {getItem(){if(storageThrows)throw Error('blocked');return seen?'1':null}};
  vm.runInNewContext(source,{URL,location,localStorage});
  return redirect;
}
assert.equal(route('/'),'https://example.com/story.html');
assert.equal(route('/cho-gan/index.html'),'https://example.com/cho-gan/story.html');
assert.equal(route('/',true),null);
assert.equal(route('/',false,true),null);
for(const path of ['/?app=1','/?code=test','/#access_token=test','/#/listing/42','/listing/42','/?error=access_denied','/?type=recovery']) {
  assert.equal(route(path),null,`Must preserve ${path}`);
}
console.log('Passed 11 first-visit, returning-visit, auth, deep-link and storage checks.');
