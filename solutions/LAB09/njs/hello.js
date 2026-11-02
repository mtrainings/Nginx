// LAB09 - njs handlers
function hello(r) {
    r.headersOut['Content-Type'] = 'application/json';
    r.return(200, JSON.stringify({
        message: 'Hello from njs',
        method: r.method,
        uri: r.uri,
        client: r.remoteAddress,
        bucket: abBucket(r),
        ts: new Date().toISOString()
    }) + '\n');
}

// Stable A/B bucket per user (X-User header) or per client IP
function abBucket(r) {
    const id = r.headersIn['X-User'] || r.remoteAddress;
    let h = 0;
    for (let i = 0; i < id.length; i++) {
        h = (h * 31 + id.charCodeAt(i)) >>> 0;
    }
    return (h % 2) ? 'B' : 'A';
}

export default { hello, abBucket };
