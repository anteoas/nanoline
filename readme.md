# nanoline

  [nanomsg]:http://nanomsg.org/
  [chicken]:http://call-cc.org/

Bridge your nanomsg sockets to and from UNIX's stdin/stdout. This
works much like [nanomsg]'s `nanocat` with the `-A` switch, but:

- sends each line from stdin on the nanomsg socket (if applicable to protocol)
- receives messages on the nanomsg socket (if applicable to protocol):
  - outputs messages without modification on stdout (not only valid ascii)
  - outputs a single newline after each message (message boundary)

If your messages contents contains newlines, these will be
indistinguishable to the message boundaries created by nanoline. This
tool is therefore intended to be used with message formats that don't
use newlines (eg JSON).

## Installation

The usual [chicken] process:

```sh
$ git clone git@github.com:anteoas/nanoline.git
$ cd nanoline
$ chicken-install -s
```

## Usage

You can test it by running:

```sh
$ nanoline pair -b ipc://test.nn
```

And in another terminal in the same directory, try:

```sh
$ nanoline pair -c ipc://test.nn
```

Hopefully, this gives a two-way bridge between your terminals. Or try
this:

```sh
$ while date ; do sleep 1 ; done | nanoline pub --bind ipc://test.nn &
$ nanoline sub -c ipc://test.nn
```

