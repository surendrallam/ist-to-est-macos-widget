// Entry point for `npm run test:site` (`node --test docs/tests/`).
//
// Node 22+ treats a directory argument to `--test` as a single module and loads
// this file, so it imports every *.test.mjs file next to it. Node 20 searches
// the directory itself and runs the *.test.mjs files directly instead.
import { readdir } from 'node:fs/promises';

const directory = new URL('./', import.meta.url);
const files = (await readdir(directory)).filter((name) => /\.test\.m?js$/.test(name)).sort();
for (const name of files) {
  await import(new URL(name, directory).href);
}
