import ejs from "ejs";
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

cNtp      enable synchronised clock via ntp
            *true -> will enable
            false -> skip (use system clock as is)

kMap      load given keyboard mapfile
            string -> will load given <string> keyboard mapfile
            *false -> skip (use default keyboard layout)

pScheme   partition drive using scheme
            *auto -> will determine from boot mode
            gpt | mbr -> explicitly use given scheme
            false -> skip (use drive layout as is)

pSwap     include swap partition with given size (if partitioning)
            true -> 1 GB
            number -> <number> GB
            *memory -> equal to size of system memory
            false | 0 -> no swap partition

pFs       filesystem to use for root partition (if partitioning)
            string | *btrfs -> use with mkfs.<string>
`;
}

function install(options: {
  template: (data: {
    cNtp: false | true;
    kMap: false | string;
    pScheme: false | "auto" | "gpt" | "mbr";
    pSwap: false | true | number | "memory";
    pFs: string | "btrfs";
  }) => string;
  query: Record<string, string>;
}): string {
  const { query, template } = options;
  return template({
    cNtp: (() => {
      const value = query["cNtp"];
      if (!value) {
        if ("cNtp" in query) {
          return true;
        }
        return true;
      } else if (value === "false" || value === "n") {
        return false;
      } else if (value === "true" || value === "y") {
        return true;
      }
      throw new Error("query.cNtp invalid value");
    })(),
    kMap: (() => {
      const value = query["kMap"];
      if (!value) {
        if ("kMap" in query) {
          throw new Error("query.kMap expected value");
        }
        return false;
      }
      return value;
    })(),
    pScheme: (() => {
      const value = query["pScheme"];
      if (!value) {
        if ("pScheme" in query) {
          throw new Error("query.pScheme expected value");
        }
        return "auto";
      } else if (value === "false" || value === "n") {
        return false;
      } else if (value === "auto" || value === "a") {
        return "auto";
      } else if (value === "gpt" || value === "g") {
        return "gpt";
      } else if (value === "mbr" || value === "m") {
        return "mbr";
      }
      throw new Error("query.pScheme invalid value");
    })(),
    pSwap: (() => {
      const value = query["pSwap"];
      if (!value) {
        if ("pSwap" in query) {
          throw new Error("query.pSwap expected value");
        }
        return "memory";
      } else if (value === "false" || value === "n") {
        return false;
      } else if (value === "true" || value === "y") {
        return true;
      } else if (value === "memory" || value === "m") {
        return "memory";
      }
      const valueNumber = parseInt(value, 10);
      if (Number.isNaN(valueNumber)) {
        throw new Error("query.pSwap invalid number");
      }
      return valueNumber;
    })(),
    pFs: (() => {
      const value = query["pFs"];
      if (!value) {
        if ("pFs" in query) {
          throw new Error("query.pFs expected value");
        }
        return "btrfs";
      }
      return value;
    })(),
  });
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
