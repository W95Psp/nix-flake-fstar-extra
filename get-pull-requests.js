const https = require('https');
const fs = require('fs');
const crypto = require('crypto');

const ua = 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.1 (KHTML, like Gecko) Chrome/13.0.782.112 Safari/535.1';

let get = url => (a, r) => 
    https.get(url, {headers: {'User-Agent': ua}}, res => {
	if(res.statusCode === 301 || res.statusCode === 302)
	    get(res.headers.location)(a, r);
	else {
	    let b = [];
	    res.on("data", d => b.push(d));
	    res.on("end", _ => a(Buffer.concat(b).toString()));
	}
    });

let getData = url => new Promise(get(url));

(async () => {
    let prs = JSON.parse(await getData('https://api.github.com/repos/FStarLang/FStar/pulls'));
    let full = await Promise.all(prs.map(async pr => 
	Object.assign(pr, {
	    patch_hash: crypto.createHash('sha256').update(await getData(pr.patch_url)).digest('base64'),
	    diff_hash: crypto.createHash('sha256').update(await getData(pr.diff_url)).digest('base64')
	})
    ));
    fs.writeFileSync('pull-requests.json', JSON.stringify(full, null, 4));
})();

