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

cNtp      false | *true
          enable synchronised clock via ntp
            true -> will enable
            false -> skip

kMap      *false | string
          load given keyboard mapfile
            string -> will load given <string> keyboard mapfile
            false -> skip

pScheme   false | *auto | gpt | mbr
          partition drive with
            auto -> will determine from boot mode
            gpt | mbr -> explicitly use given scheme
            false -> skip partitioning completely

pSwap     false | true | number | *memory
          include swap partition with given size when partitioning
            true -> 1 GB
            number -> <number> GB
            memory -> equal to size of system memory
            false | 0 -> no swap partition
`;
}

function install(options: {
  template: (data: {
    clock_ntp: false | true;
    keyboard_mapfile: false | string;
    partition_scheme?: false | "auto" | "gpt" | "mbr";
    partition_swap: false | true | number | "memory";
  }) => string;
  query: Record<string, string>;
}): string {
  const { query, template } = options;
  return template({
    clock_ntp: (() => {
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
    keyboard_mapfile: (() => {
      const value = query["kMap"];
      if (!value) {
        if ("kMap" in query) {
          throw new Error("query.kMap expected value");
        }
        return false;
      }
      return value;
    })(),
    partition_swap: (() => {
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
      } else {
        const valueNumber = parseInt(value, 10);
        if (Number.isNaN(valueNumber)) {
          throw new Error("query.pSwap invalid number");
        }
        return valueNumber;
      }
    })(),
    partition_scheme: (() => {
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
  });
}

const app = Express();
const template = ejs.compile(fs.readFileSync("./install.ejs").toString());

app.get("/install.sh", (req, res) => {
  const query = req.query as Record<string, string>;

  if ("help" in query) {
    return res.send(help());
  }

  return res.send(install({ template, query }));
});

const host = "0.0.0.0";
const port = 2020;
app.listen(port, host, () => {
  console.log(`listening: http://${host}:${port}/install.sh`);
});
