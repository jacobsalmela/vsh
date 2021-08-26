<p align="center">
    <a href="https://jacobsalmela.com/">
        <img src="https://user-images.githubusercontent.com/3843505/108062431-64a89900-701f-11eb-825c-7948c1bc6c62.png" width="250" height="250" alt="vshell">
    </a>
    <br>
    <strong>Vshell</strong><br>
    A new shell written in Vlang, optimized for software engineering.
</p>



## Current State

- `vsh` will run commands on the local system when you press enter
- commands are appended to `.v_history`
- simple up/down partial functionality

## Contributing

It the wild west right now, so just make a PR and we'll get it merged in.

## Building

```bash
# clone v to a folder you are in
git clone https://github.com/vlang/v.git v-vsh
pushd v-vsh
  # workaround for unsolved bug, #24
  sed -i.bak 's/c.paused = true/c.paused = false/' vlib/term/ui/termios_nix.c.v
  make
popd

git clone https://github.com/jacobsalmela/vsh.git
pushd vsh
  ../v-vsh/v .
popd
```

# MVP
See [https://github.com/jacobsalmela/vsh/projects/1](https://github.com/jacobsalmela/vsh/projects/1)
