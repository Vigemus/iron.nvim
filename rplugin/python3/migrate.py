from iron.repls import available_repls
from collections import defaultdict
import os

def writeline(f, text=""):
    f.write(text + os.linesep)

def to_lua(lang, defs):
   with open("lua/iron/fts/{}.lua".format(lang), "w") as f:
        writeline(f, "local {} = {{}}".format(lang))
        writeline(f)
        for i in defs:
            writeline(f, "{}.{} = {{".format(lang, i["command"]))
            writeline(f, "  command = \"{}\",".format(i["command"]))
            if "multiline" in i:
                writeline(f, "  type = \"custom\",")
                writeline(f, "  open = \"{}\",".format(i["multiline"][0]))
                writeline(f, "  close = \"{}\",".format(i["multiline"][1]))

            writeline(f, "}")
            writeline(f)

        writeline(f, "return {}".format(lang))

if __name__ == "__main__":
    defs = defaultdict(list)
    _ = [defs[i["language"]].append(i) for i in available_repls]

    [to_lua(k, v) for k, v in defs.items()]

