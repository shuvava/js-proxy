const express = require('express');
const bodyParser = require('body-parser');
const morgan = require("morgan");
const {createProxyMiddleware} = require('http-proxy-middleware');

const PORT = process.env.PORT || "3000";
const HOST = "localhost";
const API_SERVICE_URL = process.env.API_SERVICE_URL || "https://reqres.in"

// Create Express Server
const app = express();

// Logging
morgan.token('req-body', function getRequestBody(req, res) {
    return JSON.stringify(req.body)
})
morgan.token('res-body', function getResponseBody(req, res) {
    if (res) {
        return JSON.stringify(res.body)
    }
})


function logResponseBody(req, res, next) {
    var oldWrite = res.write,
        oldEnd = res.end;

    var chunks = [];

    res.write = function (chunk) {
        chunks.push(new Buffer(chunk));

        oldWrite.apply(res, arguments);
    };

    res.end = function (chunk) {
        if (chunk)
            chunks.push(new Buffer(chunk));

        var body = Buffer.concat(chunks).toString('utf8');
        //console.log(req.path, body);
        res.body = body

        oldEnd.apply(res, arguments);
    };

    next();
}

app.use(logResponseBody);

app.use(bodyParser.json());

app.use(morgan(':remote-addr :remote-user :method :url HTTP/:http-version :status :res[content-length] :req-body :res-body - :response-time ms'));

// Info GET endpoint
app.get('/healthz', (req, res, next) => {
    res.send('alive');
});
app.use('', createProxyMiddleware({
    target: API_SERVICE_URL,
    changeOrigin: true,
    onProxyReq: function proxyReq(proxyReq, req, res) {
        if (req.body) {
            // console.log(`######## ${req.method} Request`);
            // console.log(req.body);
            let bodyData = JSON.stringify(req.body);
            // incase if content-type is application/x-www-form-urlencoded -> we need to change to application/json
            proxyReq.setHeader('Content-Type', 'application/json');
            proxyReq.setHeader('Content-Length', Buffer.byteLength(bodyData));
            // stream the content
            proxyReq.write(bodyData);
            proxyReq.end();
        }
    },
}));

// Start the Proxy
app.listen(parseInt(PORT, 10), HOST, () => {
    console.log(`Starting Proxy at ${HOST}:${PORT}`);
});