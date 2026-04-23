'use strict';

const http = require('node:http');
const https = require('node:https');

const OpenAI = require('openai');

const ZAI_API_KEY = process.env.ZAI_API_KEY;
const ZAI_BASE_URL = (process.env.ZAI_BASE_URL ?? '').replace(/\/$/, '');
const AI_TIMEOUT = Number(process.env.AI_REQUEST_TIMEOUT ?? 60000);

if (!ZAI_API_KEY) throw new Error('[openaiClient] ZAI_API_KEY is not set');
if (!ZAI_BASE_URL) throw new Error('[openaiClient] ZAI_BASE_URL is not set');
if (typeof Response !== 'function') {
  throw new Error('[openaiClient] Global Response is not available in this Node runtime');
}

const keepAliveHttpAgent = new http.Agent({ keepAlive: true });
const keepAliveHttpsAgent = new https.Agent({ keepAlive: true });

function normalizeRequestBody(body) {
  if (body == null) {
    return null;
  }

  if (typeof body === 'string' || Buffer.isBuffer(body)) {
    return body;
  }

  if (body instanceof Uint8Array) {
    return Buffer.from(body);
  }

  throw new Error(
    `[openaiClient] Unsupported request body type for custom fetch: ${Object.prototype.toString.call(body)}`,
  );
}

function applyHeaders(target, source) {
  if (!source) return;

  if (typeof source.forEach === 'function') {
    source.forEach((value, key) => {
      target[key] = value;
    });
    return;
  }

  if (Array.isArray(source)) {
    for (const [key, value] of source) {
      target[key] = value;
    }
    return;
  }

  if (typeof source === 'object') {
    Object.assign(target, source);
  }
}

function buildAbortError(url) {
  const error = new Error(`Request aborted for ${url}`);
  error.name = 'AbortError';
  return error;
}

async function ilmufetch(input, init = {}) {
  const url = new URL(typeof input === 'string' ? input : input.url);
  const transport = url.protocol === 'http:' ? http : https;
  const agent = url.protocol === 'http:' ? keepAliveHttpAgent : keepAliveHttpsAgent;
  const body = normalizeRequestBody(init.body);
  const headers = {};

  applyHeaders(headers, init.headers);

  if (body != null && headers['Content-Length'] == null && headers['content-length'] == null) {
    headers['Content-Length'] = Buffer.byteLength(body);
  }

  const timeoutMs = Number(init.timeout ?? AI_TIMEOUT);

  return new Promise((resolve, reject) => {
    let settled = false;

    const requestOptions = {
      protocol: url.protocol,
      hostname: url.hostname,
      port: url.port || (url.protocol === 'http:' ? 80 : 443),
      path: `${url.pathname}${url.search}`,
      method: init.method ?? 'GET',
      headers,
      agent,
      timeout: timeoutMs,
    };

    const finalizeReject = (error) => {
      if (settled) return;
      settled = true;
      reject(error);
    };

    const finalizeResolve = (response) => {
      if (settled) return;
      settled = true;
      resolve(response);
    };

    const req = transport.request(requestOptions, (res) => {
      const chunks = [];

      res.on('data', (chunk) => {
        chunks.push(Buffer.from(chunk));
      });

      res.on('end', () => {
        const responseBody = Buffer.concat(chunks);
        finalizeResolve(
          new Response(responseBody, {
            status: res.statusCode ?? 500,
            statusText: res.statusMessage ?? '',
            headers: res.headers,
          }),
        );
      });
    });

    req.on('timeout', () => {
      req.destroy(new Error(`ILMU custom fetch timed out after ${timeoutMs}ms for ${url}`));
    });

    req.on('error', finalizeReject);

    if (init.signal) {
      const onAbort = () => {
        req.destroy(buildAbortError(url));
      };

      if (init.signal.aborted) {
        onAbort();
        return;
      }

      init.signal.addEventListener('abort', onAbort, { once: true });
      req.on('close', () => {
        init.signal.removeEventListener('abort', onAbort);
      });
    }

    if (body != null) {
      req.write(body);
    }

    req.end();
  });
}

const client = new OpenAI({
  apiKey: ZAI_API_KEY,
  baseURL: ZAI_BASE_URL,
  timeout: AI_TIMEOUT,
  fetch: ilmufetch,
});

module.exports = {
  client,
  ilmufetch,
};
