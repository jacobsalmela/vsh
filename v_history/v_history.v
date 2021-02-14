// v_history.v -- Functions for .v_history

/* This file is part of vsh, the V SHell.

	MIT License

	Copyright (C) 2021 Jacob Salmela <me@jacobsalmela.com>

	Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice (including the next paragraph) shall be included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
module v_history

import os { create, open_append }

pub fn create(path string) {
	os.create(path) or { panic(err) }
}

pub fn append(command string, f string) {
	// open the file for appending new commands to it
	mut hist_file := os.open_append(f) or { panic(err) }

	// write the command to the history file
	hist_file.writeln(command.str()) or { panic(err) }
}
