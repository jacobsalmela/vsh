// Copyright 2021.  Jacob Salmela.  jacobsalmela.com
// vsh: a shell written in vlang and optimized for software engineering

// use the standard os library
import os { input, exec, user_os }
// interpreting what keys were entered
import term.ui as tui

struct Vsh {
mut:
	tui           &tui.Context = 0
}

fn event(e &tui.Event, x voidptr) {
	mut vsh := &Vsh(x)
	if e.typ == .key_down {
		match e.code {
			.escape { exit(0) }
			.up { println('up') }
		else {}
		}
	}
}


fn main() {
	mut vsh := &Vsh{
	}

	vsh.tui = tui.init({
		event_fn: event
		capture_events: true
	})
	vsh.tui.run()

	// // Read STDIN (this is the user typing in commands)
	// for {
	// 		// A simple prompt
	// 		prompt := 'v# '
	//
	// 		mut stdin := os.input(prompt)
	//
	// 		// builtin commands this shell can run
	// 		match stdin {
	// 			'cd' { println('cd is not yet implemented')
	// 		         continue }
	// 			'help' { println('help is not yet implemented')
	// 			         continue }
	// 			'exit' { println('Goodbye.')
	// 			         exit(0) }
	// 			else { }
	// 		}
	//
	// 		stdout := exec(stdin) or { panic(err) }
	// 		print(stdout.output)
	//
	// }

}
