import ejs from "ejs";
import { z } from "zod";
import Express from "express";
import fs from "fs";

import Package from "./package.json";

function help(): string {
  const { version } = Package;
  return `archless v${version}

usage (preview): curl <host>/install.sh
usage (execute): curl <host>/install.sh | bash

*default
true  = "true"  or "y"
false = "false" or "n"

tz        link given timezone via /usr/share/zoneinfo
            string | *UTC -> link given <string> to /etc/localtime

lang      set language locale on locale.gen and locale.conf
            string | *en_US -> use given localisation string as UTF-8

host      set hostname via /etc/hostname
            string | *arch -> use as hostname

user      set username
            string | *admin -> use as username

ucode     install ucode for cpu architecture
            *auto -> will determine cpu ucode package using lscpu
            intel | amd -> explicitly use for given cpu ucode
            none (don't install any ucode package)

ntp       enable synchronised clock via ntp
            *true -> will enable
            false -> skip (use system clock as is)

keymap    load given keyboard mapfile
            string | *US -> will load given <string> keyboard mapfile

scheme    partition drive using scheme
            *auto -> will determine from boot mode
            gpt | mbr -> explicitly use given scheme

swap      include swap partition with given size (if partitioning)
            number -> <number> GB
            *memory -> equal to size of system memory
            0 -> no swap partition

fs        filesystem to use for root partition
            string | *btrfs -> use with mkfs.<string>

`;
}

const Options = z.object({
  tz: z.string().default("UTC"),
  lang: z.string().default("en_US"),
  host: z.string().default("arch"),
  user: z.string().default("admin"),
  ucode: z.enum(["auto", "intel", "amd", "none"]).default("auto"),
  ntp: z.boolean().default(true),
  keymap: z.string().default("US"),
  scheme: z.enum(["auto", "gpt", "mbr"]).default("auto"),
  swap: z
    .union([
      z.preprocess((v) => parseInt(`${v}`, 10), z.number()),
      z.literal("memory"),
    ])
    .default("memory"),
  fs: z.string().default("btrfs"),
});

type Options = z.infer<typeof Options>;

function install(options: {
  template: (options: Options) => string;
  query: Record<string, string>;
}): string {
  const { query, template } = options;
  const $ = Options.safeParse(query);
  if (!$.success) {
    return JSON.stringify($.error.format());
  }
  return template($.data);
}

const app = Express();

app.get("/install.sh", (req, res) => {
  const query = req.query as Record<string, string>;

  if ("help" in query) {
    return res.send(help());
  }

  const template = ejs.compile(fs.readFileSync("./install.ejs").toString());
  return res.send(install({ template, query }));
});

const host = "0.0.0.0";
const port = 2020;
app.listen(port, host, () => {
  console.log(`listening: http://${host}:${port}/install.sh`);
});
