// Copyright 2021.  Jacob Salmela.  jacobsalmela.com
// vsh: a shell written in vlang and optimized for software engineering

// use the standard os library
import os { input, exec, user_os }

// A simple prompt
prompt := 'v# '

// Read STDIN (this is the user typing in commands)
for {
		stdin := input(prompt)

		// builtin commands this shell can run
		match stdin {
			'cd' { println('cd is not yet implemented')
		         continue }
			'help' { println('help is not yet implemented')
			         continue }
			'exit' { println('Goodbye.')
			         exit(0) }
			else { }
		}

		stdout := exec(stdin) or { panic(err) }
		print(stdout.output)

}
