import { join } from "node:path";
import { defineConfig } from "tsup";

const appRoot = join(__dirname);

export default defineConfig([
  {
    entry: [join(appRoot, "./src/index.ts")],
    tsconfig: join(appRoot, "./tsconfig.json"),
    sourcemap: true,
    clean: true,
  },
]);
