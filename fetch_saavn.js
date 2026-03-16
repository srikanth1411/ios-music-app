const https = require('https');

const options = {
    hostname: 'saavn.me',
    path: '/search/albums?query=telugu&limit=1',
    method: 'GET',
    headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'application/json'
    }
};

const req = https.request(options, (res) => {
    let data = '';
    res.on('data', (chunk) => { data += chunk; });
    res.on('end', () => {
        try {
            console.log('Status Code:', res.statusCode);
            console.log(JSON.stringify(JSON.parse(data), null, 2).substring(0, 500));
        } catch (e) {
            console.log('Status Code:', res.statusCode);
            console.log('Raw Data Snippet:', data.substring(0, 500));
            console.error('Parse Error:', e.message);
        }
    });
});

req.on('error', (e) => {
    console.error('Request Error:', e.message);
});

req.end();
