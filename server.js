import Fastify from "fastify";
import fastifyStatic from "@fastify/static";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

const fastify = Fastify({ logger: true });

// Serve the demo's static files from ./public (index.html + tiles/).
// The raw ABS shapefiles under ./data are deliberately NOT served.
// @fastify/static supports HTTP range requests (206 Partial Content) by
// default — exactly what PMTiles needs to fetch tile byte-ranges.
await fastify.register(fastifyStatic, {
  root: join(__dirname, "public"),
  // acceptRanges is true by default; index.html is served at "/".
});

const port = Number(process.env.PORT) || 8000;
await fastify.listen({ port, host: "0.0.0.0" });
