# encoding:utf-8
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
        payload = {}
        print(out)

        if 'out' in out:
            payload['out'] = out['out']

        if 'value' in out:
            payload['value'] = out['value']

        if 'err' in out:
            payload['error'] = out['err']

        if 'ex' in out:
            payload['ex'] = out['ex']


        queue.put(payload)


def format_payload(payload):
    ls = []
    for k, v in payload.items():
        ls.append("[{: <6}] => {}".format(k.upper(), v))
    return ls

def handler(buf, queue):

    @asyncio.coroutine
    def handler_impl():
        val = yield from queue.get()
        buf.append(format_payload(val))
        

    return handler_impl
