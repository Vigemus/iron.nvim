# encoding:utf-8
""" Currently experimental code and unhooked. """
import nrepl
import asyncio


def _connect(port_no=None):
    return nrepl.connect("nrepl://localhost:{}".format(39211))

def _connect(port_no=None):
    if not port_no:
        with open(".nrepl-port") as port:
            port_no = port.read().strip()

    return nrepl.connect("nrepl://localhost:{}".format(port_no))

def _write(ch, data):
    ch.write({"op": "eval", "code": data})
    return ch


@asyncio.coroutine
def send(queue, data):
    ch = _write(_connect(), data)

    queue.put({"in": data})

    for out in ch:
        print(out)
        queue.put(out)


def format_payload(payload):
    ls = []
    for k, v in payload.items():
        ls.append("[{: <9}] => {}".format(k.upper(), v))
    return ls

def handler(buf, queue):

    @asyncio.coroutine
    def handler_impl():
        val = yield from queue.get()
        buf.append(format_payload(val))

    return handler_impl

# eval data
def lein_prompt_eval(iron):
    try:
        cmd = iron.prompt("cmd")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        ret = nrepl_eval(iron, cmd)
        iron.call_cmd("echomsg '{}'".format(ret))

def lein_update_data_with_fn(iron):
    try:
        cmd = iron.prompt("cmd")
    except:
        iron.call_cmd("echo 'Aborting'")
    else:
        data = get_current_parens(iron)
        ret = nrepl_eval(iron, "({} {})".format(cmd, data))

        if ret is None:
            iron.call_cmd("echo 'Error with eval, aborting.'")
            return

        iron.set_register("s", ret)
        iron.call_cmd("""silent normal! mx%v%"sp`x""")

